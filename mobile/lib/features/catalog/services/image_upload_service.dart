import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';

/// Picks, compresses to < 500KB JPEG, and uploads vendor images.
class ImageUploadService {
  ImageUploadService(this._api);

  final ApiClient _api;
  final ImagePicker _picker = ImagePicker();

  /// Returns the uploaded image URL, or `null` if the user cancels or upload fails.
  Future<String?> pickAndUploadImage() async {
    if (kIsWeb) {
      throw UnsupportedError('Image upload is not supported on web');
    }

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null) return null;

    var targetPath = picked.path;

    // Iteratively compress until under 500KB.
    var quality = 85;
    while (await File(targetPath).length() > 500 * 1024 && quality > 20) {
      final outDir = Directory.systemTemp;
      final outName = '${DateTime.now().millisecondsSinceEpoch}_$quality.jpg';
      final outPath = '${outDir.path}${Platform.pathSeparator}$outName';
      final next = await FlutterImageCompress.compressAndGetFile(
        targetPath,
        outPath,
        minWidth: 1024,
        minHeight: 1024,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (next == null) break;
      targetPath = next.path;
      quality -= 10;
    }

    final file = File(targetPath);
    final filename = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'image.jpg';

    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        file.path,
        filename: filename,
      ),
    });

    final response = await _api.post('/api/vendor/upload-image', data: formData);
    final url = (response as Map<String, dynamic>?)?['imageUrl'] as String?;
    return url;
  }
}

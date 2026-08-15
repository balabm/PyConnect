import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Source for picking an image.
enum ImageSourceChoice { camera, gallery }

/// A helper service that wraps [image_picker] to handle camera captures and
/// gallery selections with proper error handling and web fallbacks.
///
/// On web, camera/gallery picking is limited; the service gracefully returns
/// null so the caller can show an appropriate message.
class FilePickerService {
  FilePickerService(this._picker);
  final ImagePicker _picker;

  /// Picks a single image from the specified source.
  /// Returns the [File] or null if the user cancelled or the platform is
  /// unsupported.
  Future<File?> pickImage(ImageSourceChoice choice) async {
    if (kIsWeb) return null;

    try {
      final source = choice == ImageSourceChoice.camera
          ? ImageSource.camera
          : ImageSource.gallery;

      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (xFile == null) return null;
      return File(xFile.path);
    } on Exception {
      return null;
    }
  }

  /// Convenience: pick from camera.
  Future<File?> captureFromCamera() => pickImage(ImageSourceChoice.camera);

  /// Convenience: pick from gallery.
  Future<File?> pickFromGallery() => pickImage(ImageSourceChoice.gallery);
}

final filePickerServiceProvider = Provider<FilePickerService>((ref) {
  return FilePickerService(ImagePicker());
});

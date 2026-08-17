import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

class ForceUpdateState {
  const ForceUpdateState({
    this.forceUpdate = false,
    this.minVersion = '',
    this.storeUrl = '',
  });

  final bool forceUpdate;
  final String minVersion;
  final String storeUrl;

  ForceUpdateState copyWith({
    bool? forceUpdate,
    String? minVersion,
    String? storeUrl,
  }) {
    return ForceUpdateState(
      forceUpdate: forceUpdate ?? this.forceUpdate,
      minVersion: minVersion ?? this.minVersion,
      storeUrl: storeUrl ?? this.storeUrl,
    );
  }
}

class ForceUpdateNotifier extends StateNotifier<ForceUpdateState> {
  ForceUpdateNotifier() : super(const ForceUpdateState());

  final Dio _dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));

  Future<void> checkAppVersion(String flavor) async {
    try {
      final response = await _dio.get('/api/config/app-versions');
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return;

      final minVersion = _minVersionFor(flavor, data) ?? '1.0.0';
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final needsUpdate = _compareVersions(currentVersion, minVersion) < 0;

      state = state.copyWith(
        forceUpdate: needsUpdate,
        minVersion: minVersion,
        storeUrl: _storeUrlFor(flavor),
      );
    } catch (_) {
      // Fail open so the app remains usable if the config endpoint is down.
      state = state.copyWith(forceUpdate: false);
    }
  }

  String? _minVersionFor(String flavor, Map<String, dynamic> data) {
    final key = switch (flavor) {
      'consumer' => 'consumerMinVersion',
      'driver' => 'captainMinVersion',
      'partner' => 'partnerMinVersion',
      _ => 'consumerMinVersion',
    };
    return data[key] as String?;
  }

  String _storeUrlFor(String flavor) {
    final package = switch (flavor) {
      'consumer' => 'com.pondyconnect.app',
      'driver' => 'com.pondyconnect.driver',
      'partner' => 'com.pondyconnect.partner',
      _ => 'com.pondyconnect.app',
    };

    if (kIsWeb) {
      return 'https://play.google.com/store/apps/details?id=$package';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'https://apps.apple.com/app/idYOUR_APP_ID';
    }
    return 'https://play.google.com/store/apps/details?id=$package';
  }

  int _compareVersions(String a, String b) {
    List<int> parse(String v) {
      return v
          .split('.')
          .map((p) => int.tryParse(p) ?? 0)
          .toList();
    }

    final partsA = parse(a);
    final partsB = parse(b);

    for (var i = 0; i < 3; i++) {
      final x = i < partsA.length ? partsA[i] : 0;
      final y = i < partsB.length ? partsB[i] : 0;
      if (x != y) return x.compareTo(y);
    }

    return 0;
  }
}

final forceUpdateProvider =
    StateNotifierProvider<ForceUpdateNotifier, ForceUpdateState>(
  (ref) => ForceUpdateNotifier(),
);

Future<void> launchStoreUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

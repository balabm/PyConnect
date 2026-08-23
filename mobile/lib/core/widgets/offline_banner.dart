import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// A simple connectivity checker that pings the API health endpoint.
/// Polling starts in [start] and must be stopped in [dispose].
/// Requires [failureThreshold] consecutive failures before declaring
/// offline, and a single success to declare back online.
class ConnectivityChecker extends ChangeNotifier {
  ConnectivityChecker({this.failureThreshold = 10});

  final int failureThreshold;

  Dio? _dio;
  bool _isOnline = true;
  int _consecutiveFailures = 0;
  Timer? _timer;
  bool _started = false;

  bool get isOnline => _isOnline;

  void start() {
    if (_started) return;
    _started = true;
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    // Check immediately, then every 30 seconds.
    _check();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final response = await _dio!.get('/health');
      final nowOnline = response.statusCode == 200;
      _consecutiveFailures = 0;
      if (!nowOnline) _consecutiveFailures++;
      if (nowOnline != _isOnline) {
        _isOnline = nowOnline;
        notifyListeners();
      }
    } on DioException catch (_) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= failureThreshold && _isOnline) {
        _isOnline = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _dio?.close();
    _dio = null;
    super.dispose();
  }
}

/// Banner shown at the top of the screen when the API is unreachable.
/// Only starts polling in non-test (release/debug) environments.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final _checker = ConnectivityChecker();

  @override
  void initState() {
    super.initState();
    // Start in both debug and release mode so the user always sees
    // the real connectivity status.
    _checker.start();
  }

  @override
  void dispose() {
    _checker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // In demo mode, completely suppress the network banner so transient
    // Wi-Fi blips during a pitch don't show a scary orange error.
    if (AppConfig.isDemoMode) return widget.child;
    return ListenableBuilder(
      listenable: _checker,
      builder: (context, child) {
        return Column(
          children: [
            if (!_checker.isOnline)
              Material(
                color: Colors.amber.shade900,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No Internet Connection',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: child!),
          ],
        );
      },
      child: widget.child,
    );
  }
}

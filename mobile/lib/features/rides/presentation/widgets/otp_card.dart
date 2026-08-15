import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers.dart';

/// OTP prompt card shown when a driver is assigned or has arrived.
/// During testing (mock OTP mode), the actual OTP code is displayed.
/// In production, falls back to "Check your SMS / app notification".
class OtpCard extends ConsumerStatefulWidget {
  const OtpCard({super.key, required this.ride});

  final Map<String, dynamic> ride;

  @override
  ConsumerState<OtpCard> createState() => _OtpCardState();
}

class _OtpCardState extends ConsumerState<OtpCard> {
  String? _peekedOtp;
  bool _peeked = false;

  @override
  void initState() {
    super.initState();
    _peekOtp();
  }

  Future<void> _peekOtp() async {
    if (_peeked) return;
    _peeked = true;
    final rideId = widget.ride['id'] as String?;
    if (rideId == null) return;

    try {
      final api = ref.read(ridesApiProvider);
      final otp = await api.peekRideOtp(rideId);
      if (otp != null && otp.isNotEmpty && mounted) {
        setState(() => _peekedOtp = otp);
      }
    } catch (_) {
      // Silent — peek is a testing convenience
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.ride['status'] as String? ?? '';
    final arrived = status.toLowerCase() == 'arrivedatpickup';

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.password, color: AppTheme.sky, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arrived
                          ? 'Share your OTP with the driver'
                          : 'Your OTP is ready',
                      style: TextStyle(
                        color: AppTheme.sky,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Show this code to your driver to start the ride',
                      style: TextStyle(color: AppTheme.sky.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppTheme.sky.withValues(alpha: 0.4), width: 2),
            ),
            child: _peekedOtp != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.password, color: AppTheme.sky, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _peekedOtp!,
                        style: TextStyle(
                          color: AppTheme.sky,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          letterSpacing: 8,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, color: AppTheme.sky, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Check your SMS / app notification',
                        style: TextStyle(
                          color: AppTheme.sky,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

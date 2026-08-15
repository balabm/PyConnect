import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pondyconnect/features/auth/presentation/phone_entry_screen.dart';
import 'package:pondyconnect/features/auth/presentation/otp_verify_screen.dart';
import 'package:pondyconnect/features/auth/presentation/profile_screen.dart';
import 'package:pondyconnect/features/auth/application/auth_controller.dart';
import '../../helpers/test_overrides.dart';

void main() {
  group('Auth Screens', () {
    testWidgets('phone entry validates 10-digit number', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(),
          child: const MaterialApp(home: PhoneEntryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Type 5 digits — button should be disabled (onPressed == null)
      await tester.enterText(find.byType(TextField), '12345');
      await tester.pump();

      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNull);

      // Type 10 digits — button should be enabled
      await tester.enterText(find.byType(TextField), '9000000099');
      await tester.pump();

      final btnEnabled = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btnEnabled.onPressed, isNotNull);
    });

    testWidgets('OTP entry screen renders with verify button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...buildOverrides(),
            otpRequestedForProvider.overrideWith((ref) => '9000000099'),
          ],
          child: const MaterialApp(home: OtpVerifyScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Should show the verify button (disabled until OTP is entered)
      expect(find.text('Verify & Continue'), findsOneWidget);
    });

    testWidgets('profile screen shows user info when authenticated', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(authenticated: true),
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('+91 9000000099'), findsOneWidget);
    });

    testWidgets('profile shows role chip for authenticated user', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(authenticated: true),
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tourist'), findsOneWidget);
    });

    testWidgets('profile shows sign out button when authenticated', (tester) async {
      // Use a taller surface so the sign out button is within the viewport.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(authenticated: true),
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('profile shows guest text when not authenticated', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(authenticated: false),
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Guest'), findsOneWidget);
      expect(find.text('Not signed in'), findsOneWidget);
    });
  });
}

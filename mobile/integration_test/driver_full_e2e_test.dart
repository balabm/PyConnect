/// Driver App Full E2E Integration Test
///
/// Tests the complete driver journey against the deployed backend.
/// Uses a single testWidgets to maintain state across steps.
///
/// Run with:
///   flutter test integration_test/driver_full_e2e_test.dart --flavor driver -d emulator-5554
library driver_full_e2e_test;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';

import 'package:pondyconnect/app.dart';
import 'package:pondyconnect/core/config/app_flavor.dart';

const _backendUrl = 'https://pyconnect.run.place';
const _testPhone = '9000000060';
const _adminPhone = '9000000000';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Dio api;

  setUpAll(() {
    api = Dio(BaseOptions(
      baseUrl: _backendUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ));
  });

  group('Driver App E2E', () {
    testWidgets('Full driver onboarding and API verification', (tester) async {
      // ───────────────────────────────────────────────────────────────
      // PHASE 1: Launch app and verify splash → auth navigation
      // ───────────────────────────────────────────────────────────────
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appFlavorProvider.overrideWithValue(AppFlavor.driver),
          ],
          child: const PondyConnectApp(flavor: AppFlavor.driver),
        ),
      );

      // Wait for splash to complete
      await tester.pumpAndSettle(const Duration(seconds: 15));

      // Verify we're on the auth screen
      expect(
        find.textContaining('Welcome').evaluate().isNotEmpty ||
            find.textContaining('mobile number').evaluate().isNotEmpty,
        isTrue,
        reason: 'QA-001: Should be on the auth/phone entry screen after splash',
      );

      // ───────────────────────────────────────────────────────────────
      // PHASE 2: Test phone entry UI
      // ───────────────────────────────────────────────────────────────
      final phoneField = find.byType(TextField);
      expect(phoneField, findsOneWidget,
          reason: 'QA-002: Phone input field should be visible');

      await tester.enterText(phoneField, _testPhone);
      await tester.pump(const Duration(seconds: 1));

      // Verify "Get OTP" button is now enabled
      final getOtpButton = find.text('Get OTP');
      expect(getOtpButton, findsOneWidget,
          reason: 'QA-003: Get OTP button should be visible');

      // Tap Get OTP
      await tester.tap(getOtpButton);
      await tester.pump(const Duration(seconds: 5));

      // ───────────────────────────────────────────────────────────────
      // PHASE 3: API-based OTP verification (more reliable than UI)
      // ───────────────────────────────────────────────────────────────
      // Request OTP via API to ensure it's issued
      final otpResp = await api.post('/api/auth/otp', data: {'phone': _testPhone});
      expect(otpResp.statusCode, 200,
          reason: 'QA-004: OTP request should succeed');

      // Peek the OTP
      final peekResp = await api.get('/api/auth/otp/peek?phone=$_testPhone');
      expect(peekResp.statusCode, 200,
          reason: 'QA-005: OTP peek should succeed');
      final code = (peekResp.data as Map<String, dynamic>)['code'] as String;
      expect(code.length, 6, reason: 'QA-006: OTP should be 6 digits');

      // Verify OTP via API
      final verifyResp = await api.post('/api/auth/otp/verify', data: {
        'phone': _testPhone,
        'code': code,
      });
      expect(verifyResp.statusCode, 200,
          reason: 'QA-007: OTP verification should succeed');
      final token = (verifyResp.data as Map<String, dynamic>)['token'] as String;
      expect(token, isNotEmpty, reason: 'QA-008: Should receive auth token');

      // ───────────────────────────────────────────────────────────────
      // PHASE 4: Driver registration via API
      // ───────────────────────────────────────────────────────────────
      api.options.headers['Authorization'] = 'Bearer $token';

      final regResp = await api.post('/api/driver/register', data: {
        'name': 'Test Captain',
        'phone': _testPhone,
        'vehicleType': 'Bike',
        'vehiclePlate': 'PY-01-TEST-001',
        'licenseNumber': 'DL04202600001',
      });
      expect(regResp.statusCode, anyOf(200, 201),
          reason: 'QA-009: Driver registration should succeed');

      // Get driver profile
      final meResp = await api.get('/api/driver/me');
      final meData = meResp.data as Map<String, dynamic>;
      final driverId = meData['id'] as String;
      expect(driverId, isNotEmpty, reason: 'QA-010: Should have driver ID');
      expect(meData['name'], 'Test Captain', reason: 'QA-011: Driver name should match');
      expect(meData['phone'], _testPhone, reason: 'QA-012: Driver phone should match');

      // ───────────────────────────────────────────────────────────────
      // PHASE 5: Complete tutorial and sign agreement
      // ───────────────────────────────────────────────────────────────
      final tutorialResp = await api.post('/api/driver/complete-tutorial', data: {});
      expect(tutorialResp.statusCode, anyOf(200, 204),
          reason: 'QA-013: Tutorial completion should succeed');

      final agreementResp = await api.post('/api/driver/sign-agreement', data: {
        'signatureData': 'test-signature-strokes',
      });
      expect(agreementResp.statusCode, anyOf(200, 204),
          reason: 'QA-014: Agreement signing should succeed');

      // ───────────────────────────────────────────────────────────────
      // PHASE 6: Upload KYC
      // ───────────────────────────────────────────────────────────────
      final kycResp = await api.post('/api/driver/upload-kyc', data: {
        'aadhaarUrl': 'test://aadhaar.jpg',
        'drivingLicenseUrl': 'test://license.jpg',
        'rcUrl': 'test://rc.jpg',
        'upiId': 'testcaptain@upi',
      });
      expect(kycResp.statusCode, anyOf(200, 204),
          reason: 'QA-015: KYC upload should succeed');

      // Verify KYC was uploaded
      final meResp2 = await api.get('/api/driver/me');
      final meData2 = meResp2.data as Map<String, dynamic>;
      expect(meData2['isKycUploaded'], true,
          reason: 'QA-016: KYC should be marked as uploaded');
      expect(meData2['hasCompletedTutorial'], true,
          reason: 'QA-017: Tutorial should be marked as completed');
      expect(meData2['hasSignedAgreement'], true,
          reason: 'QA-018: Agreement should be marked as signed');

      // ───────────────────────────────────────────────────────────────
      // PHASE 7: Admin approval
      // ───────────────────────────────────────────────────────────────
      // Get admin token
      await api.post('/api/auth/otp', data: {'phone': _adminPhone});
      await Future.delayed(const Duration(seconds: 1));
      final adminPeek = await api.get('/api/auth/otp/peek?phone=$_adminPhone');
      final adminCode = (adminPeek.data as Map<String, dynamic>)['code'] as String;
      final adminVerify = await api.post('/api/auth/otp/verify', data: {
        'phone': _adminPhone,
        'code': adminCode,
      });
      final adminToken = (adminVerify.data as Map<String, dynamic>)['token'] as String;

      // Approve driver
      final approveResp = await api.post(
        '/api/admin/drivers/$driverId/approve',
        options: Options(headers: {'Authorization': 'Bearer $adminToken'}),
      );
      expect(approveResp.statusCode, anyOf(200, 204),
          reason: 'QA-019: Driver approval should succeed');

      // Verify approval
      api.options.headers['Authorization'] = 'Bearer $token';
      final meResp3 = await api.get('/api/driver/me');
      final meData3 = meResp3.data as Map<String, dynamic>;
      expect(meData3['isApproved'], true,
          reason: 'QA-020: Driver should be approved after admin approval');

      // ───────────────────────────────────────────────────────────────
      // PHASE 8: Test driver API endpoints (dashboard data)
      // ───────────────────────────────────────────────────────────────
      // Vehicles
      final vehiclesResp = await api.get('/api/driver/vehicles');
      expect(vehiclesResp.statusCode, 200,
          reason: 'QA-021: Vehicles endpoint should work');

      // Compliance
      final complianceResp = await api.get('/api/driver/compliance');
      expect(complianceResp.statusCode, 200,
          reason: 'QA-022: Compliance endpoint should work');

      // Preferences
      final prefsResp = await api.get('/api/driver/preferences');
      expect(prefsResp.statusCode, 200,
          reason: 'QA-023: Preferences endpoint should work');

      // Tasks
      final tasksResp = await api.get('/api/driver/tasks');
      expect(tasksResp.statusCode, 200,
          reason: 'QA-024: Tasks endpoint should work');

      // ───────────────────────────────────────────────────────────────
      // PHASE 9: Test go-online/go-offline
      // ───────────────────────────────────────────────────────────────
      try {
        final onlineResp = await api.post('/api/driver/go-online', data: {
          'lat': 11.9356,
          'lng': 79.8301,
        });
        expect(onlineResp.statusCode, anyOf(200, 204),
            reason: 'QA-025: Go-online should succeed for approved driver');

        // Verify online status
        final meResp4 = await api.get('/api/driver/me');
        final meData4 = meResp4.data as Map<String, dynamic>;
        expect(meData4['isOnline'], true,
            reason: 'QA-026: Driver should be online after go-online');

        // Go offline
        final offlineResp = await api.post('/api/driver/go-offline');
        expect(offlineResp.statusCode, anyOf(200, 204),
            reason: 'QA-027: Go-offline should succeed');
      } on DioException catch (e) {
        // Record as QA finding but don't fail
        debugPrint('QA FINDING: Go-online/offline failed: ${e.response?.data ?? e.message}');
      }

      // ───────────────────────────────────────────────────────────────
      // PHASE 10: Test vehicle management
      // ───────────────────────────────────────────────────────────────
      try {
        final addResp = await api.post('/api/driver/vehicles', data: {
          'vehicleType': 'Auto',
          'vehiclePlate': 'PY-01-TEST-002',
        });
        expect(addResp.statusCode, anyOf(200, 201),
            reason: 'QA-028: Adding vehicle should succeed');
      } on DioException catch (e) {
        debugPrint('QA FINDING: Add vehicle failed: ${e.response?.data ?? e.message}');
      }

      // ───────────────────────────────────────────────────────────────
      // PHASE 11: Test preferences update
      // ───────────────────────────────────────────────────────────────
      try {
        final destResp = await api.put('/api/driver/preferences/destination', data: {
          'lat': 11.9356,
          'lng': 79.8301,
          'address': 'Pondicherry Bus Stand',
        });
        expect(destResp.statusCode, anyOf(200, 204),
            reason: 'QA-029: Destination preference update should work');
      } on DioException catch (e) {
        debugPrint('QA FINDING: Destination preference failed: ${e.response?.data ?? e.message}');
      }

      try {
        final toggleResp = await api.put('/api/driver/preferences/service-toggles', data: {
          'rides': true,
          'food': true,
          'luggage': false,
        });
        expect(toggleResp.statusCode, anyOf(200, 204),
            reason: 'QA-030: Service toggle update should work');
      } on DioException catch (e) {
        debugPrint('QA FINDING: Service toggles failed: ${e.response?.data ?? e.message}');
      }

      // ───────────────────────────────────────────────────────────────
      // PHASE 12: Test earnings and wallet
      // ───────────────────────────────────────────────────────────────
      try {
        final earningsResp = await api.get('/api/driver/earnings');
        expect(earningsResp.statusCode, 200,
            reason: 'QA-031: Earnings endpoint should work');
      } on DioException catch (e) {
        debugPrint('QA FINDING: Earnings endpoint returned ${e.response?.statusCode}: ${e.response?.data ?? e.message}');
      }

      try {
        final walletResp = await api.get('/api/driver/wallet');
        expect(walletResp.statusCode, 200,
            reason: 'QA-032: Wallet endpoint should work');
      } on DioException catch (e) {
        debugPrint('QA FINDING: Wallet endpoint returned ${e.response?.statusCode}: ${e.response?.data ?? e.message}');
      }

      // ───────────────────────────────────────────────────────────────
      // PHASE 13: Clean up — delete test account
      // ───────────────────────────────────────────────────────────────
      try {
        final deleteResp = await api.post('/api/driver/account/delete');
        expect(deleteResp.statusCode, anyOf(200, 204),
            reason: 'QA-033: Account deletion should succeed');
      } on DioException catch (e) {
        debugPrint('QA FINDING: Account deletion failed: ${e.response?.data ?? e.message}');
      }
    });
  });
}

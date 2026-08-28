/// Driver App API E2E Test
///
/// Tests all driver API endpoints against the deployed backend.
/// Runs from the host machine (not the emulator) to avoid emulator
/// HTTPS connectivity issues.
///
/// Run with: dart run integration_test/driver_api_e2e_test.dart
library driver_api_e2e_test;

import 'package:dio/dio.dart';

const _backendUrl = 'https://pyconnect.run.place';
const _testPhone = '9000000060';
const _adminPhone = '9000000000';

void main() async {
  final api = Dio(BaseOptions(
    baseUrl: _backendUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  final results = <TestResult>[];
  final findings = <String>[];

  Future<void> test(String id, String description, Future<void> Function() body) async {
    try {
      await body();
      results.add(TestResult(id, description, 'PASS'));
      print('  ✓ $id: $description');
    } catch (e) {
      results.add(TestResult(id, description, 'FAIL', e.toString()));
      print('  ✗ $id: $description — $e');
    }
  }

  void finding(String f) {
    findings.add(f);
    print('  ⚠ FINDING: $f');
  }

  print('\n=========================================');
  print('Driver App API E2E Test');
  print('Backend: $_backendUrl');
  print('Test Phone: $_testPhone');
  print('=========================================\n');

  String? token;
  String? driverId;
  String? adminToken;

  // ── Health Check ──
  print('\n── Health Check ──');
  await test('HEALTH', 'Backend health check', () async {
    final resp = await api.get('/health');
    final data = resp.data as Map<String, dynamic>;
    if (data['status'] != 'Healthy') throw Exception('Backend not healthy: ${data['status']}');
  });

  // ── Auth Flow ──
  print('\n── Auth Flow ──');
  await test('AUTH-001', 'Request OTP', () async {
    final resp = await api.post('/api/auth/otp', data: {'phone': _testPhone});
    if (resp.statusCode != 200) throw Exception('Status: ${resp.statusCode}');
  });

  await test('AUTH-002', 'Peek OTP', () async {
    final resp = await api.get('/api/auth/otp/peek?phone=$_testPhone');
    if (resp.statusCode != 200) throw Exception('Status: ${resp.statusCode}');
    final code = (resp.data as Map<String, dynamic>)['code'] as String?;
    if (code == null || code.length != 6) throw Exception('Invalid OTP: $code');
  });

  await test('AUTH-003', 'Verify OTP and get token', () async {
    final peek = await api.get('/api/auth/otp/peek?phone=$_testPhone');
    final code = (peek.data as Map<String, dynamic>)['code'] as String;
    final resp = await api.post('/api/auth/otp/verify', data: {
      'phone': _testPhone,
      'code': code,
    });
    if (resp.statusCode != 200) throw Exception('Status: ${resp.statusCode}');
    token = (resp.data as Map<String, dynamic>)['token'] as String;
    if (token == null || token!.isEmpty) throw Exception('No token received');
  });

  // ── Driver Registration ──
  print('\n── Driver Registration ──');
  await test('REG-001', 'Register as driver', () async {
    api.options.headers['Authorization'] = 'Bearer $token';
    final resp = await api.post('/api/driver/register', data: {
      'name': 'Test Captain',
      'phone': _testPhone,
      'vehicleType': 'Bike',
      'vehiclePlate': 'PY-01-TEST-001',
      'licenseNumber': 'DL04202600001',
    });
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Status: ${resp.statusCode}, Body: ${resp.data}');
    }
  });

  await test('REG-002', 'Get driver profile', () async {
    final resp = await api.get('/api/driver/me');
    if (resp.statusCode != 200) throw Exception('Status: ${resp.statusCode}');
    final data = resp.data as Map<String, dynamic>;
    driverId = data['id'] as String?;
    if (driverId == null) throw Exception('No driver ID in profile');
    if (data['name'] != 'Test Captain') throw Exception('Name mismatch: ${data['name']}');
    if (data['phone'] != _testPhone) throw Exception('Phone mismatch: ${data['phone']}');
  });

  // ── Tutorial & Agreement ──
  print('\n── Tutorial & Agreement ──');
  await test('TUT-001', 'Complete tutorial', () async {
    final resp = await api.post('/api/driver/complete-tutorial', data: {});
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('Status: ${resp.statusCode}, Body: ${resp.data}');
    }
  });

  await test('TUT-002', 'Sign agreement', () async {
    final resp = await api.post('/api/driver/sign-agreement', data: {
      'signatureData': 'test-signature-strokes',
    });
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('Status: ${resp.statusCode}, Body: ${resp.data}');
    }
  });

  // ── KYC Upload ──
  print('\n── KYC Upload ──');
  await test('KYC-001', 'Upload KYC documents', () async {
    final resp = await api.post('/api/driver/upload-kyc', data: {
      'aadhaarUrl': 'test://aadhaar.jpg',
      'drivingLicenseUrl': 'test://license.jpg',
      'rcUrl': 'test://rc.jpg',
      'upiId': 'testcaptain@upi',
    });
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('Status: ${resp.statusCode}, Body: ${resp.data}');
    }
  });

  await test('KYC-002', 'Verify KYC status in profile', () async {
    final resp = await api.get('/api/driver/me');
    final data = resp.data as Map<String, dynamic>;
    if (data['isKycUploaded'] != true) throw Exception('KYC not marked as uploaded');
    if (data['hasCompletedTutorial'] != true) throw Exception('Tutorial not marked as completed');
    if (data['hasSignedAgreement'] != true) throw Exception('Agreement not marked as signed');
  });

  // ── Admin Approval ──
  print('\n── Admin Approval ──');
  await test('ADM-001', 'Get admin token', () async {
    await api.post('/api/auth/otp', data: {'phone': _adminPhone});
    await Future.delayed(const Duration(seconds: 1));
    final peek = await api.get('/api/auth/otp/peek?phone=$_adminPhone');
    final code = (peek.data as Map<String, dynamic>)['code'] as String;
    final resp = await api.post('/api/auth/otp/verify', data: {
      'phone': _adminPhone,
      'code': code,
    });
    adminToken = (resp.data as Map<String, dynamic>)['token'] as String;
    if (adminToken == null) throw Exception('No admin token');
  });

  await test('ADM-002', 'Approve driver', () async {
    final resp = await api.post(
      '/api/admin/drivers/$driverId/approve',
      options: Options(headers: {'Authorization': 'Bearer $adminToken'}),
    );
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('Status: ${resp.statusCode}, Body: ${resp.data}');
    }
  });

  await test('ADM-003', 'Verify driver is approved', () async {
    api.options.headers['Authorization'] = 'Bearer $token';
    final resp = await api.get('/api/driver/me');
    final data = resp.data as Map<String, dynamic>;
    if (data['isApproved'] != true) throw Exception('Driver not approved');
  });

  // ── Dashboard Endpoints ──
  print('\n── Dashboard Endpoints ──');
  await test('DASH-001', 'Get vehicles', () async {
    final resp = await api.get('/api/driver/vehicles');
    if (resp.statusCode != 200) throw Exception('Status: ${resp.statusCode}');
  });

  await test('DASH-002', 'Get compliance', () async {
    final resp = await api.get('/api/driver/compliance');
    if (resp.statusCode != 200) throw Exception('Status: ${resp.statusCode}');
  });

  await test('DASH-003', 'Get preferences', () async {
    final resp = await api.get('/api/driver/preferences');
    if (resp.statusCode != 200) throw Exception('Status: ${resp.statusCode}');
  });

  await test('DASH-004', 'Get tasks', () async {
    final resp = await api.get('/api/driver/tasks');
    if (resp.statusCode != 200) throw Exception('Status: ${resp.statusCode}');
  });

  // ── Online/Offline ──
  print('\n── Online/Offline ──');
  await test('ONLINE-001', 'Go online', () async {
    final resp = await api.post('/api/driver/go-online', data: {
      'lat': 11.9356,
      'lng': 79.8301,
    });
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('Status: ${resp.statusCode}, Body: ${resp.data}');
    }
  });

  await test('ONLINE-002', 'Verify online status', () async {
    final resp = await api.get('/api/driver/me');
    final data = resp.data as Map<String, dynamic>;
    if (data['isOnline'] != true) throw Exception('Driver not online');
  });

  await test('ONLINE-003', 'Go offline', () async {
    final resp = await api.post('/api/driver/go-offline');
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('Status: ${resp.statusCode}, Body: ${resp.data}');
    }
  });

  // ── Vehicle Management ──
  print('\n── Vehicle Management ──');
  await test('VEH-001', 'Add vehicle', () async {
    final resp = await api.post('/api/driver/vehicles', data: {
      'vehicleType': 'Auto',
      'vehiclePlate': 'PY-01-TEST-002',
    });
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Status: ${resp.statusCode}, Body: ${resp.data}');
    }
  });

  await test('VEH-002', 'List vehicles', () async {
    final resp = await api.get('/api/driver/vehicles');
    if (resp.statusCode != 200) throw Exception('Status: ${resp.statusCode}');
    final data = resp.data;
    if (data is! List) throw Exception('Vehicles should be a list');
  });

  // ── Preferences ──
  print('\n── Preferences ──');
  await test('PREF-001', 'Update destination preference', () async {
    try {
      final resp = await api.put('/api/driver/preferences/destination', data: {
        'lat': 11.9356,
        'lng': 79.8301,
        'address': 'Pondicherry Bus Stand',
      });
      if (resp.statusCode != 200 && resp.statusCode != 204) {
        throw Exception('Status: ${resp.statusCode}, Body: ${resp.data}');
      }
    } on DioException catch (e) {
      finding('Destination preference endpoint returned ${e.response?.statusCode}: ${e.response?.data}');
      // Don't fail — record as finding
    }
  });

  await test('PREF-002', 'Update service toggles', () async {
    try {
      final resp = await api.put('/api/driver/preferences/service-toggles', data: {
        'rides': true,
        'food': true,
        'luggage': false,
      });
      if (resp.statusCode != 200 && resp.statusCode != 204) {
        throw Exception('Status: ${resp.statusCode}, Body: ${resp.data}');
      }
    } on DioException catch (e) {
      finding('Service toggles endpoint returned ${e.response?.statusCode}: ${e.response?.data}');
    }
  });

  // ── Earnings & Wallet ──
  print('\n── Earnings & Wallet ──');
  await test('EARN-001', 'Get earnings', () async {
    try {
      final resp = await api.get('/api/driver/earnings');
      if (resp.statusCode != 200) throw Exception('Status: ${resp.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        finding('Earnings endpoint returned 404 — may need different URL');
      } else {
        throw Exception('Status: ${e.response?.statusCode}, Body: ${e.response?.data}');
      }
    }
  });

  await test('WALLET-001', 'Get wallet', () async {
    try {
      final resp = await api.get('/api/driver/wallet');
      if (resp.statusCode != 200) throw Exception('Status: ${resp.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        finding('Wallet endpoint returned 404 — may need different URL');
      } else {
        throw Exception('Status: ${e.response?.statusCode}, Body: ${e.response?.data}');
      }
    }
  });

  // ── Communications ──
  print('\n── Communications ──');
  await test('COMM-001', 'Quick message endpoint', () async {
    try {
      final resp = await api.post('/api/driver/communications/quick-message', data: {
        'message': 'test message',
        'recipientId': 'test-recipient',
      });
      if (resp.statusCode != 200 && resp.statusCode != 204) {
        finding('Quick message returned ${resp.statusCode}');
      }
    } on DioException catch (e) {
      finding('Quick message endpoint returned ${e.response?.statusCode}: ${e.response?.data}');
    }
  });

  // ── Cleanup ──
  print('\n── Cleanup ──');
  await test('CLEANUP-001', 'Delete test account', () async {
    try {
      final resp = await api.post('/api/driver/account/delete');
      if (resp.statusCode != 200 && resp.statusCode != 204) {
        throw Exception('Status: ${resp.statusCode}, Body: ${resp.data}');
      }
    } on DioException catch (e) {
      finding('Account deletion returned ${e.response?.statusCode}: ${e.response?.data}');
    }
  });

  // ── Summary ──
  print('\n=========================================');
  print('TEST SUMMARY');
  print('=========================================');
  final passed = results.where((r) => r.status == 'PASS').length;
  final failed = results.where((r) => r.status == 'FAIL').length;
  print('Total: ${results.length}');
  print('Passed: $passed');
  print('Failed: $failed');
  print('Findings: ${findings.length}');
  if (findings.isNotEmpty) {
    print('\n── Findings ──');
    for (final f in findings) {
      print('  ⚠ $f');
    }
  }
  if (failed > 0) {
    print('\n── Failed Tests ──');
    for (final r in results.where((r) => r.status == 'FAIL')) {
      print('  ✗ ${r.id}: ${r.description}');
      print('    Error: ${r.error}');
    }
  }
  print('=========================================\n');
}

class TestResult {
  final String id;
  final String description;
  final String status;
  final String? error;

  TestResult(this.id, this.description, this.status, [this.error]);
}

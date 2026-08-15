import 'package:pondyconnect/core/storage/token_storage.dart';

/// In-memory TokenStorage for tests — avoids FlutterSecureStorage
/// which is not available in the test environment.
class FakeTokenStorage extends TokenStorage {
  String? _token;

  FakeTokenStorage({String? initialToken}) : _token = initialToken;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

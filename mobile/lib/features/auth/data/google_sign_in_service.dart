import 'package:google_sign_in/google_sign_in.dart';

/// Wraps the `google_sign_in` plugin and exposes a Google [idToken]
/// that the backend can verify.
class GoogleSignInService {
  GoogleSignInService({String? serverClientId, GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile'],
              serverClientId: serverClientId,
            );

  final GoogleSignIn _googleSignIn;

  /// Starts the Google sign-in flow and returns the user's [GoogleSignInAccount]
  /// together with a verified [idToken].
  ///
  /// Returns `null` if the user cancels the flow or no account is available.
  /// Throws if the account cannot authenticate (e.g. missing OAuth client setup).
  Future<GoogleSignInAccount?> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;

    final authentication = await account.authentication;
    if (authentication.idToken == null || authentication.idToken!.isEmpty) {
      throw const GoogleSignInException(
        'Google sign-in did not return an idToken. '
        'Ensure a web client ID is configured in google-services.json or .env.',
      );
    }

    return account;
  }

  Future<String?> getIdToken() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;

    final authentication = await account.authentication;
    return authentication.idToken;
  }

  Future<void> signOut() => _googleSignIn.signOut();

  Future<void> disconnect() => _googleSignIn.disconnect();
}

class GoogleSignInException implements Exception {
  const GoogleSignInException(this.message);
  final String message;

  @override
  String toString() => 'GoogleSignInException: $message';
}

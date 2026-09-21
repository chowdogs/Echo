import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_auth_service.dart' show AuthException;

/// Obtains a Google ID token for the person signing in.
///
/// This is only the *identity* half of the flow: it proves who the user is to
/// Google and hands back an ID token. [FirebaseAuthService.signInWithGoogle]
/// then trades that token for a Firebase session, so the rest of the app never
/// has to know which provider someone used.
class GoogleAuthService {
  GoogleAuthService({required this.serverClientId, this.iosClientId});

  /// The Web (server) OAuth client id. Google mints the ID token *for* this
  /// client, and Firebase only accepts tokens minted for the project's web
  /// client — so this is required on every platform, not just the web.
  final String serverClientId;

  /// The iOS OAuth client id from `GoogleService-Info.plist`. Ignored on
  /// other platforms.
  final String? iosClientId;

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    // Only Apple platforms take a per-app client id; Android resolves its own
    // OAuth client from the package name + signing certificate, and passing a
    // foreign client id there breaks the flow.
    final bool isApple =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    await GoogleSignIn.instance.initialize(
      clientId: isApple ? iosClientId : null,
      serverClientId: serverClientId,
    );
    _initialized = true;
  }

  /// True when the current platform can run the interactive sign-in flow.
  /// The web implementation requires a rendered Google button instead, so the
  /// UI hides the option there rather than offering something that can't work.
  Future<bool> isSupported() async {
    try {
      await _ensureInitialized();
      return GoogleSignIn.instance.supportsAuthenticate();
    } catch (_) {
      return false;
    }
  }

  /// Runs the Google account picker and returns the resulting ID token.
  ///
  /// Returns null when the user backs out — a cancellation is a normal
  /// outcome, not an error worth showing them.
  Future<String?> signIn() async {
    try {
      await _ensureInitialized();

      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate();
      final String? idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          'Google did not return a sign-in token. Please try again.',
        );
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthException(_friendly(e));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('Could not sign in with Google.');
    }
  }

  /// Clears the cached Google account so the next sign-in shows the picker.
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Never let a sign-out failure block logging out of Echo itself.
    }
  }

  String _friendly(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
      case GoogleSignInExceptionCode.interrupted:
        return 'Google sign-in was cancelled.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Google sign-in is not configured correctly for this app.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google sign-in is unavailable on this device.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in could not be shown. Please try again.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'That is a different Google account than expected.';
      case GoogleSignInExceptionCode.unknownError:
        return 'Could not sign in with Google. Please try again.';
    }
  }
}

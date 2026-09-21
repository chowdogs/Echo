import 'package:flutter/foundation.dart';

import '../models/auth_session.dart';
import '../services/board_storage.dart';
import '../services/firebase_auth_service.dart';
import '../services/google_auth_service.dart';

enum AuthStatus { unknown, loggedOut, loggedIn }

/// Owns the sign-in state: who is logged in, and the register/login/logout
/// actions. Persists the session so the user stays signed in across restarts,
/// and refreshes the token on startup.
class AuthController extends ChangeNotifier {
  AuthController({
    required FirebaseAuthService auth,
    required BoardStorage storage,
    GoogleAuthService? google,
  }) : _auth = auth,
       _storage = storage,
       _google = google;

  final FirebaseAuthService _auth;
  final BoardStorage _storage;

  /// Optional Google provider. Null in tests, and on platforms where the
  /// interactive flow is unsupported the UI simply omits the button.
  final GoogleAuthService? _google;

  AuthStatus _status = AuthStatus.unknown;
  AuthSession? _session;
  bool _busy = false;
  String? _error;
  bool _googleAvailable = false;

  AuthStatus get status => _status;
  AuthSession? get session => _session;
  bool get isLoggedIn => _status == AuthStatus.loggedIn && _session != null;
  bool get busy => _busy;
  String? get error => _error;

  /// Whether to offer "Continue with Google" on this platform.
  bool get googleAvailable => _googleAvailable;

  /// Restores a saved session at startup and refreshes its token.
  Future<void> init() async {
    // Decide up front whether the Google button can be offered here, so the
    // sign-in screen never shows a control that would fail on this platform.
    _googleAvailable = await (_google?.isSupported() ?? Future<bool>.value(false));

    final AuthSession? saved = await _storage.loadSession();
    if (saved == null) {
      _set(status: AuthStatus.loggedOut);
      return;
    }
    try {
      final AuthSession refreshed = await _auth.refresh(saved);
      _session = refreshed;
      await _storage.saveSession(refreshed);
    } catch (_) {
      // Offline or refresh failed — fall back to the stored session.
      _session = saved;
    }
    _set(status: AuthStatus.loggedIn);
  }

  Future<bool> login(String email, String password) =>
      _run(() => _auth.login(email, password));

  Future<bool> register(String email, String password) =>
      _run(() => _auth.register(email, password));

  /// Signs in with Google, then trades the Google token for a Firebase
  /// session. A cancelled picker resolves quietly — it is not a failure.
  Future<bool> loginWithGoogle() async {
    final GoogleAuthService? google = _google;
    if (google == null) {
      _set(error: 'Google sign-in is not available on this device.');
      return false;
    }

    _set(busy: true, error: null);
    try {
      final String? googleIdToken = await google.signIn();
      if (googleIdToken == null) {
        _set(busy: false); // Cancelled — leave the form as it was.
        return false;
      }

      final AuthSession s = await _auth.signInWithGoogle(googleIdToken);
      _session = s;
      await _storage.saveSession(s);
      _set(busy: false, status: AuthStatus.loggedIn);
      return true;
    } on AuthException catch (e) {
      _set(busy: false, error: e.message);
      return false;
    } catch (_) {
      _set(busy: false, error: 'Something went wrong. Please try again.');
      return false;
    }
  }

  Future<bool> _run(Future<AuthSession> Function() action) async {
    _set(busy: true, error: null);
    try {
      final AuthSession s = await action();
      _session = s;
      await _storage.saveSession(s);
      _set(busy: false, status: AuthStatus.loggedIn);
      return true;
    } on AuthException catch (e) {
      _set(busy: false, error: e.message);
      return false;
    } catch (_) {
      _set(busy: false, error: 'Something went wrong. Please try again.');
      return false;
    }
  }

  Future<void> logout() async {
    // Clear the cached Google account too, so the next sign-in shows the
    // account picker rather than silently reusing the last one.
    await _google?.signOut();
    await _storage.clearSession();
    _session = null;
    _set(status: AuthStatus.loggedOut, error: null);
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void _set({AuthStatus? status, bool? busy, Object? error = _unset}) {
    if (status != null) _status = status;
    if (busy != null) _busy = busy;
    if (!identical(error, _unset)) _error = error as String?;
    notifyListeners();
  }

  static const Object _unset = Object();
}

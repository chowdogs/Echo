import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/auth_session.dart';

/// A friendly, already-explained authentication failure.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Email/password authentication against Firebase Authentication's REST API
/// (Google Identity Toolkit). No FlutterFire SDK required — just HTTP.
///
///   * REGISTER — POST accounts:signUp
///   * LOGIN    — POST accounts:signInWithPassword
///   * REFRESH  — POST securetoken.googleapis.com/v1/token
class FirebaseAuthService {
  FirebaseAuthService({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const String _idBase = 'identitytoolkit.googleapis.com';
  static const String _tokenBase = 'securetoken.googleapis.com';

  Future<AuthSession> register(String email, String password) =>
      _signUpOrIn('accounts:signUp', email, password);

  Future<AuthSession> login(String email, String password) =>
      _signUpOrIn('accounts:signInWithPassword', email, password);

  Future<AuthSession> _signUpOrIn(
    String path,
    String email,
    String password,
  ) async {
    final Map<String, dynamic> body = await _post(
      Uri.https(_idBase, '/v1/$path', <String, String>{'key': apiKey}),
      <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'returnSecureToken': true,
      },
    );

    final Object? idToken = body['idToken'];
    final Object? refreshToken = body['refreshToken'];
    final Object? uid = body['localId'];
    if (idToken is! String || refreshToken is! String || uid is! String) {
      throw const AuthException(
        'Unexpected response from the sign-in service.',
      );
    }

    return AuthSession(
      uid: uid,
      email: email.trim(),
      idToken: idToken,
      refreshToken: refreshToken,
    );
  }

  /// Exchanges the long-lived refresh token for a fresh [idToken].
  Future<AuthSession> refresh(AuthSession session) async {
    final Map<String, dynamic> body = await _post(
      Uri.https(_tokenBase, '/v1/token', <String, String>{'key': apiKey}),
      <String, dynamic>{
        'grant_type': 'refresh_token',
        'refresh_token': session.refreshToken,
      },
    );

    final Object? idToken = body['id_token'];
    final Object? refreshToken = body['refresh_token'];
    if (idToken is! String) {
      throw const AuthException('Could not refresh the session.');
    }
    return session.copyWith(
      idToken: idToken,
      refreshToken: refreshToken is String ? refreshToken : null,
    );
  }

  Future<Map<String, dynamic>> _post(
    Uri url,
    Map<String, dynamic> payload,
  ) async {
    final http.Response resp;
    try {
      resp = await _client
          .post(
            url,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
    } on SocketException {
      throw const AuthException(
        'No internet connection. Check your network and try again.',
      );
    } on TimeoutException {
      throw const AuthException('The request timed out. Please try again.');
    } catch (_) {
      throw const AuthException('Could not reach the sign-in service.');
    }

    final Object? decoded = jsonDecode(resp.body);
    final Map<String, dynamic> map = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (resp.statusCode >= 200 && resp.statusCode < 300) return map;

    // Firebase returns { "error": { "message": "EMAIL_EXISTS", ... } }.
    final Object? error = map['error'];
    final String code = (error is Map && error['message'] is String)
        ? error['message'] as String
        : 'UNKNOWN';
    throw AuthException(_friendly(code));
  }

  /// Turns Firebase's error codes into plain messages.
  String _friendly(String code) {
    if (code.startsWith('EMAIL_EXISTS')) {
      return 'That email is already registered. Try logging in instead.';
    }
    if (code.startsWith('EMAIL_NOT_FOUND')) {
      return 'No account found with that email.';
    }
    if (code.startsWith('INVALID_PASSWORD') ||
        code.startsWith('INVALID_LOGIN_CREDENTIALS')) {
      return 'Incorrect email or password.';
    }
    if (code.startsWith('INVALID_EMAIL')) return 'That email looks invalid.';
    if (code.startsWith('WEAK_PASSWORD')) {
      return 'Password is too weak — use at least 6 characters.';
    }
    if (code.startsWith('TOO_MANY_ATTEMPTS')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (code.startsWith('USER_DISABLED')) {
      return 'This account has been disabled.';
    }
    return 'Sign-in failed. Please try again.';
  }

  void dispose() => _client.close();
}

import 'dart:convert';

import 'package:echo/models/auth_session.dart';
import 'package:echo/services/firebase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  FirebaseAuthService service(MockClient client) =>
      FirebaseAuthService(apiKey: 'test-key', client: client);

  test('register POSTs to accounts:signUp and parses the session', () async {
    late String path;
    final MockClient client = MockClient((http.Request req) async {
      path = req.url.path;
      expect(req.method, 'POST');
      return http.Response(
        jsonEncode(<String, String>{
          'idToken': 'tok',
          'refreshToken': 'ref',
          'localId': 'uid1',
        }),
        200,
      );
    });

    final AuthSession s = await service(client).register('a@b.com', 'secret1');
    expect(path, '/v1/accounts:signUp');
    expect(s.uid, 'uid1');
    expect(s.idToken, 'tok');
    expect(s.email, 'a@b.com');
  });

  test('login POSTs to accounts:signInWithPassword', () async {
    late String path;
    final MockClient client = MockClient((http.Request req) async {
      path = req.url.path;
      return http.Response(
        jsonEncode(<String, String>{
          'idToken': 'tok',
          'refreshToken': 'ref',
          'localId': 'uid1',
        }),
        200,
      );
    });
    await service(client).login('a@b.com', 'secret1');
    expect(path, '/v1/accounts:signInWithPassword');
  });

  test('a Firebase error becomes a friendly AuthException', () async {
    final MockClient client = MockClient(
      (http.Request req) async => http.Response(
        jsonEncode(<String, dynamic>{
          'error': <String, dynamic>{'message': 'EMAIL_EXISTS'},
        }),
        400,
      ),
    );

    expect(
      () => service(client).register('a@b.com', 'secret1'),
      throwsA(
        isA<AuthException>().having(
          (AuthException e) => e.message,
          'message',
          contains('already registered'),
        ),
      ),
    );
  });

  test('refresh exchanges the refresh token for a new id token', () async {
    const AuthSession old = AuthSession(
      uid: 'uid1',
      email: 'a@b.com',
      idToken: 'old',
      refreshToken: 'ref',
    );
    final MockClient client = MockClient(
      (http.Request req) async => http.Response(
        jsonEncode(<String, String>{
          'id_token': 'fresh',
          'refresh_token': 'ref2',
        }),
        200,
      ),
    );

    final AuthSession s = await service(client).refresh(old);
    expect(s.idToken, 'fresh');
    expect(s.refreshToken, 'ref2');
    expect(s.uid, 'uid1');
  });
}

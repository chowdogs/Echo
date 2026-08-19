import 'dart:convert';

import 'package:echo/models/comm_tile.dart';
import 'package:echo/services/firebase_board_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const String base =
      'https://echo-df114-default-rtdb.asia-southeast1.firebasedatabase.app';
  const CommTile tile = CommTile(
    id: 'cold',
    label: 'Cold',
    ttsPhrase: 'I am cold.',
    icon: Icons.ac_unit_rounded,
    colorTheme: 'sky',
  );

  FirebaseBoardService authed(MockClient client) =>
      FirebaseBoardService(baseUrl: base, client: client)
        ..setAuth('user1', 'token123');

  test('requests target the user namespace and carry the auth token', () async {
    late Uri url;
    final MockClient client = MockClient((http.Request req) async {
      url = req.url;
      return http.Response('null', 200);
    });

    await authed(client).fetchTiles();
    expect(url.path, '/users/user1/tiles.json');
    expect(url.queryParameters['auth'], 'token123');
  });

  test('READ — fetchTiles parses the returned map', () async {
    final MockClient client = MockClient((http.Request req) async {
      expect(req.method, 'GET');
      return http.Response(
        jsonEncode(<String, dynamic>{'cold': tile.toJson()}),
        200,
      );
    });
    expect((await authed(client).fetchTiles()).single.label, 'Cold');
  });

  test('CREATE — putTile sends PUT /users/{uid}/tiles/{id}.json', () async {
    late String method;
    late String path;
    final MockClient client = MockClient((http.Request req) async {
      method = req.method;
      path = req.url.path;
      return http.Response('', 200);
    });

    await authed(client).putTile(tile);
    expect(method, 'PUT');
    expect(path, '/users/user1/tiles/cold.json');
  });

  test('UPDATE — patchTile sends PATCH', () async {
    late String method;
    final MockClient client = MockClient((http.Request req) async {
      method = req.method;
      return http.Response('', 200);
    });
    await authed(client).patchTile(tile);
    expect(method, 'PATCH');
  });

  test('DELETE — deleteTile sends DELETE', () async {
    late String method;
    late String path;
    final MockClient client = MockClient((http.Request req) async {
      method = req.method;
      path = req.url.path;
      return http.Response('null', 200);
    });
    await authed(client).deleteTile('cold');
    expect(method, 'DELETE');
    expect(path, '/users/user1/tiles/cold.json');
  });

  test('LOG — logSpoken sends POST /users/{uid}/log.json', () async {
    late String method;
    late String path;
    final MockClient client = MockClient((http.Request req) async {
      method = req.method;
      path = req.url.path;
      return http.Response(jsonEncode(<String, String>{'name': '-Nabc'}), 200);
    });
    await authed(client).logSpoken('cold', 'Cold');
    expect(method, 'POST');
    expect(path, '/users/user1/log.json');
  });

  test('a non-2xx response throws FirebaseBoardException', () async {
    final MockClient client = MockClient(
      (http.Request req) async => http.Response('denied', 401),
    );
    expect(
      () => authed(client).fetchTiles(),
      throwsA(isA<FirebaseBoardException>()),
    );
  });
}

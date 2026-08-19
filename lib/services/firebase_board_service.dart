import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/comm_tile.dart';

/// A friendly, already-explained failure the caller can surface as-is.
class FirebaseBoardException implements Exception {
  const FirebaseBoardException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to a Firebase Realtime Database over its REST API.
///
/// Firebase exposes every path as a URL ending in `.json`, and the HTTP verb
/// decides the operation — which maps cleanly onto CRUD:
///
///   * READ   — GET    /tiles.json
///   * CREATE — PUT    /tiles/{id}.json
///   * UPDATE — PATCH  /tiles/{id}.json
///   * DELETE — DELETE /tiles/{id}.json
///   * LOG    — POST   /log.json   (Firebase generates the key)
///
/// The board's create/update/delete use a stable id we own; the append-only
/// usage log uses POST, where Firebase-generated keys are exactly right.
class FirebaseBoardService {
  FirebaseBoardService({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  // The signed-in user's data lives under /users/{uid}; every request carries
  // their id token so the security rules authorise it.
  String? _uid;
  String? _idToken;

  bool get hasAuth => _uid != null && _idToken != null;

  /// Points the service at a signed-in user's namespace.
  void setAuth(String uid, String idToken) {
    _uid = uid;
    _idToken = idToken;
  }

  void clearAuth() {
    _uid = null;
    _idToken = null;
  }

  Uri _uri(String path) {
    final String uid = _uid ?? '_';
    return Uri.parse('$_baseUrl/users/$uid/$path.json').replace(
      queryParameters: _idToken != null
          ? <String, String>{'auth': _idToken!}
          : null,
    );
  }

  /// READ — GET /tiles.json. Returns every stored tile (empty list if the
  /// database has none yet).
  Future<List<CommTile>> fetchTiles() async {
    final http.Response resp = await _send(() => _client.get(_uri('tiles')));
    final Object? decoded = jsonDecode(resp.body);
    if (decoded is! Map) return <CommTile>[];

    final List<CommTile> tiles = <CommTile>[];
    decoded.forEach((Object? key, Object? value) {
      if (value is Map) {
        final CommTile? tile = CommTile.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (tile != null) tiles.add(tile);
      }
    });
    return tiles;
  }

  /// CREATE — PUT /tiles/{id}.json.
  Future<void> putTile(CommTile tile) => _send(
    () =>
        _client.put(_uri('tiles/${tile.id}'), body: jsonEncode(tile.toJson())),
  );

  /// UPDATE — PATCH /tiles/{id}.json.
  Future<void> patchTile(CommTile tile) => _send(
    () => _client.patch(
      _uri('tiles/${tile.id}'),
      body: jsonEncode(tile.toJson()),
    ),
  );

  /// DELETE — DELETE /tiles/{id}.json.
  Future<void> deleteTile(String id) =>
      _send(() => _client.delete(_uri('tiles/$id')));

  /// Writes the whole board at once — used to seed the defaults the first time
  /// the database is empty, so the console immediately shows data.
  Future<void> putBoard(List<CommTile> tiles) {
    final Map<String, dynamic> map = <String, dynamic>{
      for (final CommTile t in tiles) t.id: t.toJson(),
    };
    return _send(() => _client.put(_uri('tiles'), body: jsonEncode(map)));
  }

  /// LOG — POST /log.json. Appends one "spoken" event; Firebase returns a
  /// generated key. Feeds usage analytics for caregivers.
  Future<void> logSpoken(String tileId, String label) {
    final String body = jsonEncode(<String, dynamic>{
      'tileId': tileId,
      'label': label,
      'at': DateTime.now().toIso8601String(),
    });
    return _send(() => _client.post(_uri('log'), body: body));
  }

  /// Runs [request], normalising every failure into a [FirebaseBoardException].
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response resp;
    try {
      resp = await request().timeout(const Duration(seconds: 12));
    } on SocketException {
      throw const FirebaseBoardException('No internet connection.');
    } on TimeoutException {
      throw const FirebaseBoardException('The request timed out.');
    } catch (_) {
      throw const FirebaseBoardException('Could not reach the database.');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw FirebaseBoardException('Database error (${resp.statusCode}).');
    }
    return resp;
  }

  void dispose() => _client.close();
}

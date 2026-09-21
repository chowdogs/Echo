import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/comm_tile.dart';
import '../models/pairing.dart';

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
    _targetUid = null;
  }

  /// The account whose data this service reads and writes.
  ///
  /// Normally that is the signed-in user. A controller (guardian) points it at
  /// the patient they manage instead: the requests still carry the
  /// controller's own token, and the security rules authorise them through the
  /// pairing grant. Passing null returns to the signed-in user's own data.
  String? _targetUid;

  void setTarget(String? uid) => _targetUid = uid;
  String? get targetUid => _targetUid;

  Uri _uri(String path) {
    final String uid = _targetUid ?? _uid ?? '_';
    // An empty path addresses the account node itself.
    final String suffix = path.isEmpty ? '' : '/$path';
    return Uri.parse('$_baseUrl/users/$uid$suffix.json').replace(
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

  /// READ — GET /log.json. Returns the stored usage history, oldest first, so
  /// the caregiver dashboard can show real numbers across devices.
  Future<List<Utterance>> fetchLog() async {
    final http.Response resp = await _send(() => _client.get(_uri('log')));
    final Object? decoded = jsonDecode(resp.body);
    if (decoded is! Map) return <Utterance>[];

    final List<Utterance> log = <Utterance>[];
    decoded.forEach((Object? key, Object? value) {
      if (value is Map) {
        final Utterance? entry = Utterance.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (entry != null) log.add(entry);
      }
    });
    log.sort((Utterance a, Utterance b) => a.spokenAt.compareTo(b.spokenAt));
    return log;
  }

  /// Whether this platform can hold Firebase's event-stream open.
  ///
  /// Firebase's REST API *does* push changes, over Server-Sent Events. The
  /// catch is the client: the browser's HTTP implementation buffers a response
  /// until it completes, so a stream that never completes delivers nothing.
  /// Native platforms stream fine, so they get true push and the web falls
  /// back to a short poll.
  static bool get supportsStreaming => !kIsWeb;

  /// Emits every time the data under [path] changes.
  ///
  /// Each emission only says *that* something changed; the caller re-reads to
  /// get it. That keeps one parsing path for both push and poll, instead of
  /// two subtly different ones that could disagree.
  Stream<String> watch(String path) async* {
    final http.Request request = http.Request('GET', _uri(path))
      ..headers['Accept'] = 'text/event-stream';

    final http.StreamedResponse response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FirebaseBoardException('Live updates failed '
          '(${response.statusCode}).');
    }

    await for (final String line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!line.startsWith('event:')) continue;
      final String event = line.substring('event:'.length).trim();
      // "keep-alive" and "auth_revoked" are not data changes.
      if (event == 'put' || event == 'patch') yield event;
    }
  }

  /// READ — GET /settings.json. The patient's board layout and appearance.
  ///
  /// These used to be device-local preferences. They live in the cloud now
  /// because a controller sets them up on the patient's behalf, from their own
  /// device — the patient never has to open a settings screen at all.
  Future<Map<String, dynamic>> fetchSettings() async {
    final http.Response resp = await _send(
      () => _client.get(_uri('settings')),
    );
    final Object? decoded = jsonDecode(resp.body);
    if (decoded is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(decoded);
  }

  /// UPDATE — PATCH /settings.json. Only the named fields are touched, so a
  /// controller changing the layout cannot clobber the theme, or vice versa.
  Future<void> patchSettings({
    int? gridColumns,
    int? gridRows,
    bool? darkMode,
  }) {
    final Map<String, dynamic> body = <String, dynamic>{
      if (gridColumns != null) 'gridColumns': gridColumns,
      if (gridRows != null) 'gridRows': gridRows,
      if (darkMode != null) 'darkMode': darkMode,
    };
    if (body.isEmpty) return Future<void>.value();
    return _send(
      () => _client.patch(_uri('settings'), body: jsonEncode(body)),
    );
  }

  /// SOS — POST /sos.json. Raises an emergency event on the patient's record
  /// for their guardians to pick up. Fired alongside the local alarm, never
  /// instead of it: the sound on the patient's own device is the primary
  /// signal, and this is the remote echo of it.
  Future<void> raiseSos(String label) {
    final String body = jsonEncode(<String, dynamic>{
      'at': DateTime.now().toIso8601String(),
      'label': label,
    });
    return _send(() => _client.post(_uri('sos'), body: body));
  }

  /// READ — GET /sos.json. The targeted account's emergency history, oldest
  /// first. A guardian polls this to surface new alerts.
  Future<List<SosEvent>> fetchSos() async {
    final http.Response resp = await _send(() => _client.get(_uri('sos')));
    final Object? decoded = jsonDecode(resp.body);
    if (decoded is! Map) return <SosEvent>[];

    final List<SosEvent> events = <SosEvent>[];
    decoded.forEach((Object? key, Object? value) {
      if (key is String && value is Map) {
        final SosEvent? event = SosEvent.fromJson(
          key,
          Map<String, dynamic>.from(value),
        );
        if (event != null) events.add(event);
      }
    });
    events.sort((SosEvent a, SosEvent b) => a.at.compareTo(b.at));
    return events;
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

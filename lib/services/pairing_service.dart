import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/pairing.dart';

/// A friendly, already-explained pairing failure.
class PairingException implements Exception {
  const PairingException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Links a patient account to a controller (guardian) account.
///
/// The handshake is deliberately one-directional, because only the patient may
/// hand out access to their own data:
///
///   1. The patient publishes a short-lived code at `/pairings/{code}`.
///   2. The guardian scans or types that code and stamps their own uid on it.
///   3. The patient's device sees the claim and writes the actual grant.
///   4. The code is deleted — it is single use.
///
/// So a guessed code alone grants nothing: the patient's device is always the
/// one that completes the link, while the pairing screen is open.
class PairingService {
  PairingService({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  String? _uid;
  String? _idToken;

  bool get hasAuth => _uid != null && _idToken != null;
  String? get uid => _uid;

  void setAuth(String uid, String idToken) {
    _uid = uid;
    _idToken = idToken;
  }

  void clearAuth() {
    _uid = null;
    _idToken = null;
  }

  Uri _uri(String path) {
    return Uri.parse('$_baseUrl/$path.json').replace(
      queryParameters: _idToken != null
          ? <String, String>{'auth': _idToken!}
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Patient side
  // ---------------------------------------------------------------------------

  /// Publishes a fresh single-use code for the patient to show. Retries on the
  /// astronomically unlikely collision with a live code rather than handing
  /// two patients the same one.
  Future<String> createPairing({
    required String patientUid,
    required String patientEmail,
  }) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final String code = PairingCode.generate();
      final Map<String, dynamic>? existing = await readPairing(code);
      if (existing != null) continue;

      await _send(
        () => _client.put(
          _uri('pairings/$code'),
          body: jsonEncode(<String, dynamic>{
            'patientUid': patientUid,
            'patientEmail': patientEmail,
            'createdAt': DateTime.now().toIso8601String(),
          }),
        ),
      );
      return code;
    }
    throw const PairingException('Could not create a code. Please try again.');
  }

  Future<Map<String, dynamic>?> readPairing(String code) async {
    final http.Response resp = await _send(
      () => _client.get(_uri('pairings/$code')),
    );
    final Object? decoded = jsonDecode(resp.body);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> deletePairing(String code) =>
      _send(() => _client.delete(_uri('pairings/$code')));

  /// Records the grant, both ways: `/access` is what the security rules check,
  /// and `/controllerOf` is the index that lets a guardian list their patients
  /// without being able to read anyone else's.
  Future<void> grantAccess({
    required String patientUid,
    required String patientEmail,
    required String controllerUid,
    required String controllerEmail,
  }) async {
    final String now = DateTime.now().toIso8601String();

    await _send(
      () => _client.put(
        _uri('access/$patientUid/$controllerUid'),
        body: jsonEncode(<String, dynamic>{
          'email': controllerEmail,
          'linkedAt': now,
        }),
      ),
    );
    await _send(
      () => _client.put(
        _uri('controllerOf/$controllerUid/$patientUid'),
        body: jsonEncode(<String, dynamic>{
          'email': patientEmail,
          'linkedAt': now,
        }),
      ),
    );
  }

  /// Removes a guardian's access. Only the patient can do this, so the call
  /// lives here rather than on the controller's side.
  Future<void> revokeAccess({
    required String patientUid,
    required String controllerUid,
  }) async {
    await _send(
      () => _client.delete(_uri('access/$patientUid/$controllerUid')),
    );
    await _send(
      () => _client.delete(_uri('controllerOf/$controllerUid/$patientUid')),
    );
  }

  /// The guardians currently allowed to manage [patientUid].
  Future<List<PatientLink>> fetchControllers(String patientUid) =>
      _fetchLinks('access/$patientUid');

  // ---------------------------------------------------------------------------
  // Controller (guardian) side
  // ---------------------------------------------------------------------------

  /// Stamps the guardian's identity onto a code the patient is showing.
  /// Returns the patient's uid so the caller can start watching for the grant.
  Future<String> claimPairing({
    required String code,
    required String controllerUid,
    required String controllerEmail,
  }) async {
    final Map<String, dynamic>? pairing = await readPairing(code);
    if (pairing == null) {
      throw const PairingException(
        'That code is not valid. Ask for a new one.',
      );
    }

    final Object? patientUid = pairing['patientUid'];
    if (patientUid is! String || patientUid.isEmpty) {
      throw const PairingException('That code is not valid any more.');
    }
    if (patientUid == controllerUid) {
      throw const PairingException(
        'That is your own code — ask the patient for theirs.',
      );
    }

    final Object? createdAt = pairing['createdAt'];
    if (createdAt is String) {
      final DateTime? made = DateTime.tryParse(createdAt);
      if (made != null &&
          DateTime.now().difference(made) > PairingCode.validity) {
        throw const PairingException(
          'That code has expired. Ask for a new one.',
        );
      }
    }

    await _send(
      () => _client.patch(
        _uri('pairings/$code'),
        body: jsonEncode(<String, dynamic>{
          'claimedBy': controllerUid,
          'claimedEmail': controllerEmail,
          'claimedAt': DateTime.now().toIso8601String(),
        }),
      ),
    );
    return patientUid;
  }

  /// The patients [controllerUid] is allowed to manage.
  Future<List<PatientLink>> fetchLinkedPatients(String controllerUid) =>
      _fetchLinks('controllerOf/$controllerUid');

  Future<List<PatientLink>> _fetchLinks(String path) async {
    final http.Response resp = await _send(() => _client.get(_uri(path)));
    final Object? decoded = jsonDecode(resp.body);
    if (decoded is! Map) return <PatientLink>[];

    final List<PatientLink> links = <PatientLink>[];
    decoded.forEach((Object? key, Object? value) {
      if (key is String && value is Map) {
        final PatientLink? link = PatientLink.fromJson(
          key,
          Map<String, dynamic>.from(value),
        );
        if (link != null) links.add(link);
      }
    });
    links.sort(
      (PatientLink a, PatientLink b) => a.linkedAt.compareTo(b.linkedAt),
    );
    return links;
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response resp;
    try {
      resp = await request().timeout(const Duration(seconds: 12));
    } on SocketException {
      throw const PairingException('No internet connection.');
    } on TimeoutException {
      throw const PairingException('The request timed out.');
    } catch (_) {
      throw const PairingException('Could not reach the server.');
    }

    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw const PairingException(
        'You do not have permission for that. Check the pairing and try again.',
      );
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw PairingException('Pairing failed (${resp.statusCode}).');
    }
    return resp;
  }

  void dispose() => _client.close();
}

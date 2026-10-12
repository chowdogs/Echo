import 'dart:convert';

import 'package:echo/models/pairing.dart';
import 'package:echo/services/pairing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Covers guardian pairing (TS-08), its limits (TS-09) and revocation (TS-14).
///
/// This is the most security-sensitive code in the app: it decides who may
/// read and write a patient's board. Verifying it by hand on two devices is
/// slow and easy to get wrong, so the rules it enforces are pinned here.
void main() {
  const String base = 'https://echo-test.firebasedatabase.app';

  PairingService authed(MockClient client) =>
      PairingService(baseUrl: base, client: client)
        ..setAuth('guardian-1', 'token123');

  group('PairingCode', () {
    test('generates two capitals followed by four digits', () {
      for (var i = 0; i < 200; i++) {
        final String code = PairingCode.generate();
        expect(
          RegExp(r'^[A-Z]{2}[0-9]{4}$').hasMatch(code),
          isTrue,
          reason: 'bad code: $code',
        );
      }
    });

    test('accepts a typed code however the user punctuates it', () {
      expect(PairingCode.parse('QX4821'), 'QX4821');
      expect(PairingCode.parse('qx4821'), 'QX4821');
      expect(PairingCode.parse('QX-4821'), 'QX4821');
      expect(PairingCode.parse('  qx 4821 '), 'QX4821');
    });

    test('accepts the QR payload form', () {
      final String payload = PairingCode.toQrPayload('AB1234');
      expect(payload, 'ECHO:AB1234');
      expect(PairingCode.parse(payload), 'AB1234');
    });

    test('rejects anything that is not one of ours', () {
      // An unrelated QR — a Wi-Fi config, a receipt — must not pair.
      expect(PairingCode.parse('WIFI:S:home;'), isNull);
      expect(PairingCode.parse('1234AB'), isNull, reason: 'wrong order');
      expect(PairingCode.parse('ABC123'), isNull, reason: 'three letters');
      expect(PairingCode.parse('AB123'), isNull, reason: 'too short');
      expect(PairingCode.parse('AB12345'), isNull, reason: 'too long');
      expect(PairingCode.parse(''), isNull);
    });
  });

  group('createPairing', () {
    test('publishes a well-formed code at /pairings/{code}', () async {
      late String path;
      late Map<String, dynamic> body;

      final MockClient client = MockClient((http.Request req) async {
        path = req.url.path;
        if (req.method == 'GET') return http.Response('null', 200);
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      });

      final String code = await authed(client).createPairing(
        patientUid: 'patient-9',
        patientEmail: 'p@example.com',
      );

      expect(PairingCode.isValid(code), isTrue);
      expect(path, '/pairings/$code.json');
      expect(body['patientUid'], 'patient-9');
      expect(body['createdAt'], isA<String>());
    });
  });

  group('claimPairing', () {
    MockClient respondingWith(Map<String, dynamic>? record, {
      void Function(http.Request)? onWrite,
    }) {
      return MockClient((http.Request req) async {
        if (req.method == 'GET') {
          return http.Response(jsonEncode(record), 200);
        }
        onWrite?.call(req);
        return http.Response('{}', 200);
      });
    }

    test('stamps the guardian on the code and returns the patient', () async {
      http.Request? write;
      final MockClient client = respondingWith(
        <String, dynamic>{
          'patientUid': 'patient-9',
          'createdAt': DateTime.now().toIso8601String(),
        },
        onWrite: (http.Request r) => write = r,
      );

      final String patientUid = await authed(client).claimPairing(
        code: 'AB1234',
        controllerUid: 'guardian-1',
        controllerEmail: 'g@example.com',
      );

      expect(patientUid, 'patient-9');
      expect(write!.method, 'PATCH');
      final Map<String, dynamic> body =
          jsonDecode(write!.body) as Map<String, dynamic>;
      expect(body['claimedBy'], 'guardian-1');
    });

    test('rejects a code that was never issued', () async {
      final MockClient client = respondingWith(null);
      expect(
        () => authed(client).claimPairing(
          code: 'ZZ9999',
          controllerUid: 'guardian-1',
          controllerEmail: 'g@example.com',
        ),
        throwsA(isA<PairingException>()),
      );
    });

    test('rejects an expired code', () async {
      final MockClient client = respondingWith(<String, dynamic>{
        'patientUid': 'patient-9',
        'createdAt': DateTime.now()
            .subtract(PairingCode.validity + const Duration(minutes: 1))
            .toIso8601String(),
      });

      expect(
        () => authed(client).claimPairing(
          code: 'AB1234',
          controllerUid: 'guardian-1',
          controllerEmail: 'g@example.com',
        ),
        throwsA(
          isA<PairingException>().having(
            (PairingException e) => e.message,
            'message',
            contains('expired'),
          ),
        ),
      );
    });

    test('refuses to let an account pair with itself', () async {
      final MockClient client = respondingWith(<String, dynamic>{
        'patientUid': 'guardian-1',
        'createdAt': DateTime.now().toIso8601String(),
      });

      expect(
        () => authed(client).claimPairing(
          code: 'AB1234',
          controllerUid: 'guardian-1',
          controllerEmail: 'g@example.com',
        ),
        throwsA(isA<PairingException>()),
      );
    });
  });

  group('grantAccess / revokeAccess', () {
    test('a grant writes both the rule record and the index', () async {
      final List<String> puts = <String>[];
      final MockClient client = MockClient((http.Request req) async {
        if (req.method == 'PUT') puts.add(req.url.path);
        return http.Response('{}', 200);
      });

      await authed(client).grantAccess(
        patientUid: 'patient-9',
        patientEmail: 'p@example.com',
        controllerUid: 'guardian-1',
        controllerEmail: 'g@example.com',
      );

      // /access is what the security rules consult; /controllerOf is the
      // reverse index that lets a guardian list their patient without being
      // able to read anyone else's.
      expect(puts, contains('/access/patient-9/guardian-1.json'));
      expect(puts, contains('/controllerOf/guardian-1/patient-9.json'));
    });

    test('revoking removes both, so access cannot linger', () async {
      final List<String> deletes = <String>[];
      final MockClient client = MockClient((http.Request req) async {
        if (req.method == 'DELETE') deletes.add(req.url.path);
        return http.Response('null', 200);
      });

      await authed(client).revokeAccess(
        patientUid: 'patient-9',
        controllerUid: 'guardian-1',
      );

      expect(deletes, contains('/access/patient-9/guardian-1.json'));
      expect(deletes, contains('/controllerOf/guardian-1/patient-9.json'));
    });

    test('a permission error is reported, not swallowed', () async {
      final MockClient client = MockClient(
        (http.Request req) async => http.Response('denied', 401),
      );

      expect(
        () => authed(client).revokeAccess(
          patientUid: 'patient-9',
          controllerUid: 'guardian-1',
        ),
        throwsA(
          isA<PairingException>().having(
            (PairingException e) => e.message,
            'message',
            contains('permission'),
          ),
        ),
      );
    });
  });

  group('listing links', () {
    test('parses the guardians allowed to manage a patient', () async {
      final MockClient client = MockClient(
        (http.Request req) async => http.Response(
          jsonEncode(<String, dynamic>{
            'guardian-1': <String, dynamic>{
              'email': 'nurse@example.com',
              'linkedAt': '2026-01-02T10:00:00.000',
            },
          }),
          200,
        ),
      );

      final List<PatientLink> links = await authed(
        client,
      ).fetchControllers('patient-9');

      expect(links.length, 1);
      expect(links.single.uid, 'guardian-1');
      expect(links.single.email, 'nurse@example.com');
    });

    test('an account with no links returns empty, not an error', () async {
      final MockClient client = MockClient(
        (http.Request req) async => http.Response('null', 200),
      );
      expect(await authed(client).fetchLinkedPatients('guardian-1'), isEmpty);
    });
  });
}

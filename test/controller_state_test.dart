import 'dart:convert';

import 'package:echo/services/firebase_board_service.dart';
import 'package:echo/services/pairing_service.dart';
import 'package:echo/state/controller_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Covers the guardian role: which interface an account gets, and the limits
/// on pairing (TS-09, TS-10, TS-15).
///
/// The limits are not cosmetic — "one patient per controller" is what makes
/// every screen in the console unambiguously about one person, and the
/// three-guardian cap is what stops a board quietly becoming editable by a
/// crowd. Both are asserted here rather than trusted to the UI.
void main() {
  const String base = 'https://echo-test.firebasedatabase.app';

  /// A board backend that answers every read with an empty node, so role
  /// resolution can complete without the test caring about board contents.
  MockClient emptyBoard() => MockClient(
    (http.Request req) async => http.Response('null', 200),
  );

  ControllerState build({required MockClient pairingClient}) {
    final ControllerState state = ControllerState(
      pairing: PairingService(baseUrl: base, client: pairingClient),
      remoteBoard: FirebaseBoardService(baseUrl: base, client: emptyBoard()),
    );
    state.setAuth(
      uid: 'guardian-1',
      email: 'g@example.com',
      idToken: 'token123',
    );
    return state;
  }

  /// Answers the "which patients do I manage" read with [patients].
  MockClient linkedTo(Map<String, dynamic> patients) => MockClient(
    (http.Request req) async => http.Response(jsonEncode(patients), 200),
  );

  group('limits', () {
    test('a patient may have at most three guardians', () {
      expect(kMaxGuardiansPerPatient, 3);
    });

    test('a controller manages exactly one patient', () {
      expect(kMaxPatientsPerController, 1);
    });
  });

  group('role resolution', () {
    test('an account with no patients gets the patient interface', () async {
      final ControllerState state = build(pairingClient: linkedTo(<String, dynamic>{}));

      await state.resolveRole();

      expect(state.role, EchoRole.patient);
      expect(state.isController, isFalse);
      expect(state.patient, isNull);
      state.dispose();
    });

    test('an account with a patient becomes a controller', () async {
      final ControllerState state = build(
        pairingClient: linkedTo(<String, dynamic>{
          'patient-9': <String, dynamic>{
            'email': 'p@example.com',
            'linkedAt': '2026-01-02T10:00:00.000',
          },
        }),
      );

      await state.resolveRole();

      expect(state.role, EchoRole.controller);
      expect(state.isController, isTrue);
      expect(state.patient?.uid, 'patient-9');
      state.dispose();
    });

    test('an unreachable backend falls back to the patient interface', () async {
      // Failing closed here would lock someone out of their own board for the
      // duration of a network blip, which is the worse outcome.
      final ControllerState state = build(
        pairingClient: MockClient(
          (http.Request req) async => http.Response('denied', 401),
        ),
      );

      await state.resolveRole();

      expect(state.role, EchoRole.patient);
      state.dispose();
    });
  });

  group('connectWithCode', () {
    test('rejects a malformed code without calling the backend', () async {
      var calls = 0;
      final ControllerState state = build(
        pairingClient: MockClient((http.Request req) async {
          calls++;
          return http.Response('null', 200);
        }),
      );

      final result = await state.connectWithCode('not-a-code');

      expect(result, isNull);
      expect(state.error, contains('AB1234'));
      expect(calls, 0, reason: 'a bad code should never reach the server');
      state.dispose();
    });

    test('refuses a second patient while one is already managed', () async {
      final ControllerState state = build(
        pairingClient: linkedTo(<String, dynamic>{
          'patient-9': <String, dynamic>{
            'email': 'p@example.com',
            'linkedAt': '2026-01-02T10:00:00.000',
          },
        }),
      );
      await state.resolveRole();
      expect(state.patient?.uid, 'patient-9');

      final result = await state.connectWithCode('AB1234');

      expect(result, isNull);
      expect(state.error, contains('Disconnect'));
      // The existing pairing must survive the refused attempt.
      expect(state.patient?.uid, 'patient-9');
      state.dispose();
    });

    test('refuses when nobody is signed in', () async {
      final ControllerState state = ControllerState(
        pairing: PairingService(baseUrl: base, client: emptyBoard()),
        remoteBoard: FirebaseBoardService(baseUrl: base, client: emptyBoard()),
      );

      final result = await state.connectWithCode('AB1234');

      expect(result, isNull);
      expect(state.error, isNotNull);
      state.dispose();
    });
  });

  group('alerts', () {
    test('there are none before any emergency', () async {
      final ControllerState state = build(pairingClient: linkedTo(<String, dynamic>{}));
      expect(state.hasAlerts, isFalse);
      expect(state.alerts, isEmpty);
      state.dispose();
    });
  });

  group('signing out', () {
    test('clears the role, the patient and any alerts', () async {
      final ControllerState state = build(
        pairingClient: linkedTo(<String, dynamic>{
          'patient-9': <String, dynamic>{
            'email': 'p@example.com',
            'linkedAt': '2026-01-02T10:00:00.000',
          },
        }),
      );
      await state.resolveRole();
      expect(state.isController, isTrue);

      state.clearAuth();

      expect(state.role, EchoRole.unknown);
      expect(state.patient, isNull);
      expect(state.hasAlerts, isFalse);
      expect(state.remoteTiles, isEmpty);
      state.dispose();
    });
  });
}

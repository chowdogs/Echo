import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/comm_tile.dart';
import '../models/pairing.dart';
import '../services/firebase_board_service.dart';
import '../services/pairing_service.dart';
import '../services/tts_service.dart';
import 'tile_state.dart' show kMaxGridAxis, kMinGridAxis;

/// One emergency alert as a guardian sees it: the event plus who raised it.
typedef PatientAlert = ({PatientLink patient, SosEvent event});

/// A patient may hand control to at most this many guardians — enough for a
/// parent, a relief carer and a nurse, without the board quietly becoming
/// editable by a crowd.
const int kMaxGuardiansPerPatient = 3;

/// A guardian account manages exactly one patient. Keeping it to one is what
/// makes the controller console unambiguous: every screen is *this* patient's.
const int kMaxPatientsPerController = 1;

/// Which interface this account gets.
///
/// The two roles are exclusive on purpose. A patient's device exists to be
/// tapped and nothing else; a controller's device carries all the setup work
/// and has no board of its own. Mixing them was the mistake this replaces.
enum EchoRole { unknown, patient, controller }

/// Everything the guardian side of the app needs, plus the patient's own
/// record of who controls them.
class ControllerState extends ChangeNotifier {
  ControllerState({
    required PairingService pairing,
    required FirebaseBoardService remoteBoard,
    TtsService? tts,
  }) : _pairing = pairing,
       _board = remoteBoard,
       _tts = tts;

  final PairingService _pairing;

  /// A board service reserved for the *patient's* data, so it can be pointed
  /// at their account without disturbing anything else.
  final FirebaseBoardService _board;

  /// Speaks emergency alerts aloud. Null in tests.
  final TtsService? _tts;

  String? _uid;
  String _email = '';

  EchoRole _role = EchoRole.unknown;
  PatientLink? _patient;
  List<PatientLink> _guardians = <PatientLink>[];

  bool _busy = false;
  String? _error;

  // --- Emergency alerts -----------------------------------------------------
  Timer? _sosTimer;
  String? _seenSos;
  final List<PatientAlert> _alerts = <PatientAlert>[];

  /// In-app alerts are the whole delivery mechanism, so this is how long an
  /// emergency can go unseen. Ten seconds is responsive without thrashing the
  /// battery of a phone sitting in a carer's pocket all day.
  static const Duration sosPollInterval = Duration(seconds: 10);

  // --- The patient's board, layout and history ------------------------------
  List<CommTile> _remoteTiles = <CommTile>[];
  List<Utterance> _remoteLog = <Utterance>[];
  int _remoteColumns = 3;
  int _remoteRows = 3;
  bool _remoteDarkMode = false;
  bool _loading = false;

  EchoRole get role => _role;
  bool get isController => _role == EchoRole.controller;
  PatientLink? get patient => _patient;
  List<PatientLink> get guardians => List<PatientLink>.unmodifiable(_guardians);
  bool get canAddGuardian => _guardians.length < kMaxGuardiansPerPatient;

  bool get busy => _busy;
  bool get loading => _loading;
  String? get error => _error;

  List<PatientAlert> get alerts => List<PatientAlert>.unmodifiable(_alerts);
  bool get hasAlerts => _alerts.isNotEmpty;

  List<CommTile> get remoteTiles => List<CommTile>.unmodifiable(_remoteTiles);
  List<Utterance> get remoteLog => List<Utterance>.unmodifiable(_remoteLog);
  int get remoteColumns => _remoteColumns;
  int get remoteRows => _remoteRows;
  int get remoteTilesPerPage => _remoteColumns * _remoteRows;
  bool get remoteDarkMode => _remoteDarkMode;

  void setAuth({
    required String uid,
    required String email,
    required String idToken,
  }) {
    _uid = uid;
    _email = email;
    _pairing.setAuth(uid, idToken);
    _board.setAuth(uid, idToken);
  }

  void clearAuth() {
    stopSosWatch();
    _uid = null;
    _email = '';
    _role = EchoRole.unknown;
    _patient = null;
    _guardians = <PatientLink>[];
    _alerts.clear();
    _seenSos = null;
    _remoteTiles = <CommTile>[];
    _remoteLog = <Utterance>[];
    _pairing.clearAuth();
    _board.clearAuth();
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Works out which interface this account should get, then loads whatever
  /// that role needs. Called once after sign-in.
  Future<void> resolveRole() async {
    final String? uid = _uid;
    if (uid == null) return;

    try {
      final List<PatientLink> managed = await _pairing.fetchLinkedPatients(uid);
      _patient = managed.isEmpty ? null : managed.first;
      _role = _patient == null ? EchoRole.patient : EchoRole.controller;
      notifyListeners();

      if (_patient != null) {
        _board.setTarget(_patient!.uid);
        await loadPatient();
        startSosWatch();
      } else {
        await refreshGuardians();
      }
    } catch (_) {
      // Offline: assume the ordinary patient interface rather than locking
      // someone out of their own board.
      if (_role == EchoRole.unknown) {
        _role = EchoRole.patient;
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Patient side: who controls me
  // ---------------------------------------------------------------------------

  Future<void> refreshGuardians() async {
    final String? uid = _uid;
    if (uid == null) return;
    try {
      _guardians = await _pairing.fetchControllers(uid);
      notifyListeners();
    } catch (_) {
      // Keep the list we have.
    }
  }

  /// Revokes a guardian's control. The patient is always allowed to do this,
  /// even though they cannot do much else from their device.
  Future<void> removeGuardian(String controllerUid) async {
    final String? uid = _uid;
    if (uid == null) return;
    try {
      await _pairing.revokeAccess(
        patientUid: uid,
        controllerUid: controllerUid,
      );
      _guardians = _guardians
          .where((PatientLink g) => g.uid != controllerUid)
          .toList();
      notifyListeners();
    } on PairingException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Becoming / ceasing to be a controller
  // ---------------------------------------------------------------------------

  Future<PatientLink?> connectWithCode(String rawCode) async {
    final String? uid = _uid;
    if (uid == null) {
      _error = 'You need to be signed in to connect.';
      notifyListeners();
      return null;
    }
    if (_patient != null) {
      _error =
          'You already manage ${_patient!.displayName}. Disconnect them '
          'first — a controller account looks after one patient.';
      notifyListeners();
      return null;
    }

    final String? code = PairingCode.parse(rawCode);
    if (code == null) {
      _error = 'That code does not look right. It should be like AB1234.';
      notifyListeners();
      return null;
    }

    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final String patientUid = await _pairing.claimPairing(
        code: code,
        controllerUid: uid,
        controllerEmail: _email,
      );

      // The patient's own device writes the grant; wait for it to land.
      for (var waited = 0; waited < 45; waited++) {
        final List<PatientLink> links = await _pairing.fetchLinkedPatients(uid);
        final int index = links.indexWhere(
          (PatientLink l) => l.uid == patientUid,
        );
        if (index != -1) {
          _patient = links[index];
          _role = EchoRole.controller;
          _busy = false;
          notifyListeners();

          _board.setTarget(_patient!.uid);
          await loadPatient();
          startSosWatch();
          return _patient;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      _error =
          'The patient device did not confirm. They may already have '
          '$kMaxGuardiansPerPatient guardians, or their screen was closed.';
    } on PairingException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not connect. Please try again.';
    }

    _busy = false;
    notifyListeners();
    return null;
  }

  /// Hands the patient back. A relief nurse finishing a shift is the ordinary
  /// case, so this is a plain action rather than a buried one.
  Future<void> disconnectPatient() async {
    final String? uid = _uid;
    final PatientLink? patient = _patient;
    if (uid == null || patient == null) return;

    _busy = true;
    notifyListeners();

    try {
      await _pairing.revokeAccess(
        patientUid: patient.uid,
        controllerUid: uid,
      );
      stopSosWatch();
      _patient = null;
      _role = EchoRole.patient;
      _remoteTiles = <CommTile>[];
      _remoteLog = <Utterance>[];
      _alerts.clear();
      _seenSos = null;
      _board.setTarget(null);
      await refreshGuardians();
    } on PairingException catch (e) {
      _error = e.message;
    }

    _busy = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // The patient's board, layout and history
  // ---------------------------------------------------------------------------

  Future<void> loadPatient() async {
    final PatientLink? patient = _patient;
    if (patient == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _board.setTarget(patient.uid);
      _remoteTiles = await _board.fetchTiles();

      final Map<String, dynamic> settings = await _board.fetchSettings();
      final Object? columns = settings['gridColumns'];
      final Object? rows = settings['gridRows'];
      final Object? dark = settings['darkMode'];
      if (columns is int) {
        _remoteColumns = columns.clamp(kMinGridAxis, kMaxGridAxis);
      }
      if (rows is int) _remoteRows = rows.clamp(kMinGridAxis, kMaxGridAxis);
      if (dark is bool) _remoteDarkMode = dark;

      _remoteLog = await _board.fetchLog();
    } on FirebaseBoardException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load that patient.';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> refreshStats() async {
    final PatientLink? patient = _patient;
    if (patient == null) return;
    try {
      _board.setTarget(patient.uid);
      _remoteLog = await _board.fetchLog();
      notifyListeners();
    } catch (_) {
      // Keep the history we have.
    }
  }

  Future<void> setRemoteGrid({int? columns, int? rows}) async {
    final int nextColumns = (columns ?? _remoteColumns).clamp(
      kMinGridAxis,
      kMaxGridAxis,
    );
    final int nextRows = (rows ?? _remoteRows).clamp(
      kMinGridAxis,
      kMaxGridAxis,
    );
    if (nextColumns == _remoteColumns && nextRows == _remoteRows) return;

    _remoteColumns = nextColumns;
    _remoteRows = nextRows;
    notifyListeners();
    await _write(
      () => _board.patchSettings(
        gridColumns: _remoteColumns,
        gridRows: _remoteRows,
      ),
    );
  }

  Future<void> setRemoteDarkMode(bool value) async {
    if (_remoteDarkMode == value) return;
    _remoteDarkMode = value;
    notifyListeners();
    await _write(() => _board.patchSettings(darkMode: value));
  }

  int _idCounter = 0;

  Future<void> addRemoteTile({
    required String label,
    required String ttsPhrase,
    required IconData icon,
    required String colorTheme,
    String? imageUrl,
  }) async {
    if (_patient == null) return;

    final CommTile tile = CommTile(
      id: 'tile_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}',
      label: label,
      ttsPhrase: ttsPhrase,
      icon: icon,
      colorTheme: colorTheme,
      imageUrl: imageUrl,
    );

    _remoteTiles = <CommTile>[..._remoteTiles, tile];
    notifyListeners();
    await _write(() => _board.putTile(tile));
  }

  Future<void> updateRemoteTile(
    String id, {
    required String label,
    required String ttsPhrase,
    required IconData icon,
    required String colorTheme,
    Object? imageUrl = CommTile.keep,
  }) async {
    if (_patient == null) return;

    CommTile? updated;
    _remoteTiles = <CommTile>[
      for (final CommTile t in _remoteTiles)
        if (t.id == id)
          updated = t.copyWith(
            label: label,
            ttsPhrase: ttsPhrase,
            icon: icon,
            colorTheme: colorTheme,
            imageUrl: imageUrl,
          )
        else
          t,
    ];
    notifyListeners();

    final CommTile? target = updated;
    if (target != null) await _write(() => _board.patchTile(target));
  }

  Future<void> removeRemoteTile(String id) async {
    if (_patient == null) return;
    _remoteTiles = _remoteTiles.where((CommTile t) => t.id != id).toList();
    notifyListeners();
    await _write(() => _board.deleteTile(id));
  }

  /// Runs a write against the patient's account. Unlike a local edit there is
  /// no copy that already succeeded, so failures are surfaced.
  Future<void> _write(Future<void> Function() op) async {
    final PatientLink? patient = _patient;
    if (patient == null) return;
    try {
      _board.setTarget(patient.uid);
      await op();
    } on FirebaseBoardException catch (e) {
      _error = e.message;
      notifyListeners();
    } catch (_) {
      _error = 'That change did not save. Check your connection.';
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Emergency alerts
  // ---------------------------------------------------------------------------

  void startSosWatch() {
    if (_sosTimer != null || _patient == null) return;
    _sosTimer = Timer.periodic(sosPollInterval, (_) => _pollSos());
    unawaited(_pollSos());
  }

  void stopSosWatch() {
    _sosTimer?.cancel();
    _sosTimer = null;
  }

  Future<void> _pollSos() async {
    final PatientLink? patient = _patient;
    if (patient == null) return;

    try {
      _board.setTarget(patient.uid);
      final List<SosEvent> events = await _board.fetchSos();
      if (events.isEmpty) return;

      final String newestId = events.last.id;
      final String? seen = _seenSos;
      _seenSos = newestId;

      // The first poll only establishes a baseline — a guardian opening the
      // app should not be ambushed by every past emergency.
      if (seen == null || seen == newestId) return;

      final int seenIndex = events.indexWhere((SosEvent e) => e.id == seen);
      final List<SosEvent> fresh = seenIndex == -1
          ? <SosEvent>[events.last]
          : events.sublist(seenIndex + 1);
      if (fresh.isEmpty) return;

      for (final SosEvent event in fresh) {
        _alerts.add((patient: patient, event: event));
      }
      _announce(patient);
      notifyListeners();
    } catch (_) {
      // A patient we momentarily cannot reach is not worth an error.
    }
  }

  /// Says the emergency out loud on the guardian's device.
  ///
  /// A silent banner is useless if the phone is in a pocket, so the alert is
  /// spoken, names who it is about, and repeats once in case the first line
  /// is missed.
  void _announce(PatientLink patient) {
    final TtsService? tts = _tts;
    if (tts == null) return;

    final String who = patient.email.isNotEmpty
        ? patient.email.split('@').first
        : 'Your patient';
    final String message =
        'Emergency. $who pressed the S O S button and needs help now.';

    unawaited(() async {
      try {
        await tts.speak(message);
        await Future<void>.delayed(const Duration(seconds: 4));
        if (_alerts.isNotEmpty) await tts.speak(message);
      } catch (_) {
        // Never let a speech failure swallow the visual alert.
      }
    }());
  }

  void dismissAllAlerts() {
    if (_alerts.isEmpty) return;
    _alerts.clear();
    unawaited(_tts?.stop());
    notifyListeners();
  }

  @override
  void dispose() {
    stopSosWatch();
    super.dispose();
  }
}

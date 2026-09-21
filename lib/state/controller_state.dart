import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/comm_tile.dart';
import '../models/pairing.dart';
import '../services/firebase_board_service.dart';
import '../services/pairing_service.dart';

/// One emergency alert as a guardian sees it: the event plus who raised it.
typedef PatientAlert = ({PatientLink patient, SosEvent event});

/// The guardian half of the app.
///
/// A single account is both things at once: everyone signs in to the ordinary
/// patient interface, and *additionally* may control other accounts they have
/// been paired with. So this sits alongside [TileState] rather than replacing
/// it, and stays empty for users who have never paired with anyone.
class ControllerState extends ChangeNotifier {
  ControllerState({
    required PairingService pairing,
    required FirebaseBoardService remoteBoard,
  }) : _pairing = pairing,
       _board = remoteBoard;

  final PairingService _pairing;

  /// A board service dedicated to *other people's* boards, so pointing it at a
  /// patient can never disturb the signed-in user's own board.
  final FirebaseBoardService _board;

  String? _uid;
  String _email = '';

  List<PatientLink> _patients = <PatientLink>[];
  bool _busy = false;
  String? _error;

  // --- SOS watching ---------------------------------------------------------
  Timer? _sosTimer;

  /// The newest event id already seen per patient. Seeded on the first poll so
  /// a guardian opening the app is not ambushed by the whole history.
  final Map<String, String> _seenSos = <String, String>{};
  final List<PatientAlert> _alerts = <PatientAlert>[];

  /// How often a guardian's device checks for new alerts. In-app only, so
  /// this is the whole delivery mechanism — frequent enough to matter,
  /// spaced enough not to drain the battery.
  static const Duration sosPollInterval = Duration(seconds: 10);

  // --- Remote board editing -------------------------------------------------
  PatientLink? _openPatient;
  List<CommTile> _remoteTiles = <CommTile>[];
  bool _boardBusy = false;

  List<PatientLink> get patients => List<PatientLink>.unmodifiable(_patients);
  bool get busy => _busy;
  String? get error => _error;
  bool get isController => _patients.isNotEmpty;

  List<PatientAlert> get alerts => List<PatientAlert>.unmodifiable(_alerts);
  bool get hasAlerts => _alerts.isNotEmpty;

  PatientLink? get openPatient => _openPatient;
  List<CommTile> get remoteTiles => List<CommTile>.unmodifiable(_remoteTiles);
  bool get boardBusy => _boardBusy;

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
    _patients = <PatientLink>[];
    _alerts.clear();
    _seenSos.clear();
    _openPatient = null;
    _remoteTiles = <CommTile>[];
    _pairing.clearAuth();
    _board.clearAuth();
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Loads the accounts this guardian may control.
  Future<void> refreshPatients() async {
    final String? uid = _uid;
    if (uid == null) return;
    try {
      _patients = await _pairing.fetchLinkedPatients(uid);
      notifyListeners();
      if (_patients.isNotEmpty) startSosWatch();
    } catch (_) {
      // Offline — keep whatever list we already have.
    }
  }

  /// Claims a pairing code, then waits for the patient's device to complete
  /// the grant. Returns the newly linked patient, or null on failure.
  Future<PatientLink?> connectWithCode(String rawCode) async {
    final String? uid = _uid;
    if (uid == null) {
      _error = 'You need to be signed in to connect.';
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

      // The patient's device finishes the link; poll until it lands.
      const Duration step = Duration(seconds: 1);
      for (var waited = 0; waited < 45; waited++) {
        final List<PatientLink> links = await _pairing.fetchLinkedPatients(uid);
        final int index = links.indexWhere(
          (PatientLink l) => l.uid == patientUid,
        );
        if (index != -1) {
          _patients = links;
          _busy = false;
          notifyListeners();
          startSosWatch();
          return links[index];
        }
        await Future<void>.delayed(step);
      }

      _error =
          'The patient device did not confirm. Keep their QR screen open '
          'and try again.';
    } on PairingException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not connect. Please try again.';
    }

    _busy = false;
    notifyListeners();
    return null;
  }

  // ---------------------------------------------------------------------------
  // Emergency alerts
  // ---------------------------------------------------------------------------

  void startSosWatch() {
    if (_sosTimer != null || _uid == null) return;
    _sosTimer = Timer.periodic(sosPollInterval, (_) => _pollSos());
    unawaited(_pollSos());
  }

  void stopSosWatch() {
    _sosTimer?.cancel();
    _sosTimer = null;
  }

  Future<void> _pollSos() async {
    if (_uid == null || _patients.isEmpty) return;

    // Remember where the board was pointed; polling must not disturb an open
    // editing session.
    final String? restore = _board.targetUid;
    var raised = false;

    for (final PatientLink patient in _patients) {
      try {
        _board.setTarget(patient.uid);
        final List<SosEvent> events = await _board.fetchSos();
        if (events.isEmpty) continue;

        final String newestId = events.last.id;
        final String? seen = _seenSos[patient.uid];
        _seenSos[patient.uid] = newestId;

        // First sighting only establishes the baseline.
        if (seen == null || seen == newestId) continue;

        final int seenIndex = events.indexWhere(
          (SosEvent e) => e.id == seen,
        );
        final List<SosEvent> fresh = seenIndex == -1
            ? <SosEvent>[events.last]
            : events.sublist(seenIndex + 1);

        for (final SosEvent event in fresh) {
          _alerts.add((patient: patient, event: event));
          raised = true;
        }
      } catch (_) {
        // A patient we momentarily cannot reach is not an error worth showing.
      }
    }

    _board.setTarget(restore);
    if (raised) notifyListeners();
  }

  void dismissAlert(String eventId) {
    _alerts.removeWhere((PatientAlert a) => a.event.id == eventId);
    notifyListeners();
  }

  void dismissAllAlerts() {
    if (_alerts.isEmpty) return;
    _alerts.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Editing a patient's board remotely
  // ---------------------------------------------------------------------------

  Future<void> openPatientBoard(PatientLink patient) async {
    _openPatient = patient;
    _remoteTiles = <CommTile>[];
    _boardBusy = true;
    _error = null;
    notifyListeners();

    try {
      _board.setTarget(patient.uid);
      _remoteTiles = await _board.fetchTiles();
    } on FirebaseBoardException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load that board.';
    }

    _boardBusy = false;
    notifyListeners();
  }

  void closePatientBoard() {
    _openPatient = null;
    _remoteTiles = <CommTile>[];
    _board.setTarget(null);
    notifyListeners();
  }

  int _idCounter = 0;

  Future<void> addRemoteTile({
    required String label,
    required String ttsPhrase,
    required IconData icon,
    required String colorTheme,
    String? imageUrl,
  }) async {
    final PatientLink? patient = _openPatient;
    if (patient == null) return;

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
    await _write(patient, () => _board.putTile(tile));
  }

  Future<void> updateRemoteTile(
    String id, {
    required String label,
    required String ttsPhrase,
    required IconData icon,
    required String colorTheme,
    Object? imageUrl = CommTile.keep,
  }) async {
    final PatientLink? patient = _openPatient;
    if (patient == null) return;

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
    if (target != null) {
      await _write(patient, () => _board.patchTile(target));
    }
  }

  Future<void> removeRemoteTile(String id) async {
    final PatientLink? patient = _openPatient;
    if (patient == null) return;

    _remoteTiles = _remoteTiles.where((CommTile t) => t.id != id).toList();
    notifyListeners();
    await _write(patient, () => _board.deleteTile(id));
  }

  /// Runs a write against [patient]'s board, surfacing failures because —
  /// unlike a local edit — there is no local copy that already succeeded.
  Future<void> _write(PatientLink patient, Future<void> Function() op) async {
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

  @override
  void dispose() {
    stopSosWatch();
    super.dispose();
  }
}

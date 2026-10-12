import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/comm_tile.dart';
import '../services/board_storage.dart';
import '../services/firebase_board_service.dart';
import '../services/tts_service.dart';
import 'usage_stats.dart';

/// The nine starter tiles.
///
/// Ordering is deliberate rather than alphabetical. AAC users build muscle
/// memory for tile positions, so the most urgent needs sit in the top rows
/// where they are reachable without scanning, and the yes/no pair is kept
/// adjacent because it is almost always used as a pair.
const List<CommTile> kInitialTiles = <CommTile>[
  CommTile(
    id: 'hungry',
    label: 'Hungry',
    ttsPhrase: 'I am hungry.',
    icon: Icons.restaurant_rounded,
    colorTheme: 'amber',
  ),
  CommTile(
    id: 'thirsty',
    label: 'Thirsty',
    ttsPhrase: 'I am thirsty.',
    icon: Icons.local_cafe_rounded,
    colorTheme: 'sky',
  ),
  CommTile(
    id: 'pain',
    label: 'Pain',
    ttsPhrase: 'I am in pain.',
    icon: Icons.healing_rounded,
    colorTheme: 'rose',
  ),
  CommTile(
    id: 'restroom',
    label: 'Restroom',
    ttsPhrase: 'I need to use the restroom.',
    icon: Icons.wc_rounded,
    colorTheme: 'violet',
  ),
  CommTile(
    id: 'yes',
    label: 'Yes',
    ttsPhrase: 'Yes.',
    icon: Icons.check_rounded,
    colorTheme: 'emerald',
  ),
  CommTile(
    id: 'no',
    label: 'No',
    ttsPhrase: 'No.',
    icon: Icons.close_rounded,
    colorTheme: 'slate',
  ),
  CommTile(
    id: 'help',
    label: 'Help',
    ttsPhrase: 'I need help, please.',
    icon: Icons.support_rounded,
    colorTheme: 'orange',
  ),
  CommTile(
    id: 'play',
    label: 'Activity',
    ttsPhrase: 'I would like to do an activity.',
    icon: Icons.interests_rounded,
    colorTheme: 'teal',
  ),
  CommTile(
    id: 'sleep',
    label: 'Rest',
    ttsPhrase: 'I am tired. I would like to rest.',
    icon: Icons.bedtime_rounded,
    colorTheme: 'indigo',
  ),
];

/// The emergency phrase is not part of the editable board, so it lives here
/// rather than in [kInitialTiles] — a caregiver must not be able to delete it.
const CommTile kEmergencyTile = CommTile(
  id: 'emergency',
  label: 'Emergency',
  ttsPhrase: 'I need help right now. This is an emergency.',
  icon: Icons.sos_rounded,
  colorTheme: 'rose',
);

/// The three bottom-nav destinations. Stats is no longer here — it lives as a
/// page pushed from Settings.
enum EchoTab { speak, emergency, settings }

/// Board layout bounds. Kept deliberately small at both ends: one tile per
/// page is a legitimate setting for a user with very low motor precision, and
/// past five per axis the targets stop being dependable to tap.
const int kMinGridAxis = 1;
const int kMaxGridAxis = 5;
const int kDefaultGridColumns = 3;
const int kDefaultGridRows = 3;

/// How long the scanning highlight rests on each tile, in seconds.
///
/// One second suits a practised user; six gives someone with a slow or
/// unreliable press time to commit. Getting this wrong in either direction
/// makes the board unusable, which is why it is adjustable rather than fixed.
const int kMinScanSeconds = 1;
const int kMaxScanSeconds = 6;
const int kDefaultScanSeconds = 2;

/// App-wide state. The Flutter counterpart of the React context this app was
/// first prototyped with.
class TileState extends ChangeNotifier {
  TileState({
    BoardStorage? storage,
    FirebaseBoardService? firebase,
    TtsService? tts,
  }) : _storage = storage ?? BoardStorage(),
       _firebase = firebase,
       _tts = tts {
    _load();
  }

  final BoardStorage _storage;

  /// Optional cloud backend (Firebase Realtime Database). When null — as in
  /// tests — the app runs purely on local storage and makes no network calls.
  final FirebaseBoardService? _firebase;

  /// Optional Text-to-Speech engine. When null — as in tests — the app records
  /// the utterance but produces no audio (no platform plugin is touched).
  final TtsService? _tts;

  List<CommTile> _tiles = List<CommTile>.of(kInitialTiles);
  EchoTab _activeTab = EchoTab.speak;
  final List<Utterance> _utterances = <Utterance>[];

  // Light is the default, per request; the Settings toggle flips this.
  ThemeMode _themeMode = ThemeMode.light;

  // Board layout: how many tiles fill one page. A caregiver tunes this to the
  // user's motor precision — fewer tiles means bigger, easier targets — and
  // the board pages instead of shrinking once the tiles overflow a page.
  int _gridColumns = kDefaultGridColumns;
  int _gridRows = kDefaultGridRows;

  /// Whether the account's board has been read from the cloud at least once.
  /// Until it has, an empty cloud result cannot be trusted to mean "empty".
  bool _cloudLoaded = false;

  // Switch scanning: a highlight steps through the tiles on its own and the
  // user presses anything at all to choose the highlighted one. For someone
  // who cannot reliably land a finger on a specific tile — the people this app
  // exists for — this is the difference between a usable board and a useless
  // one, so it lives in the account and a controller can turn it on remotely.
  bool _scanningEnabled = false;
  int _scanSeconds = kDefaultScanSeconds;

  /// Loads the board and theme from local storage at startup (instant and
  /// offline-safe). The per-account cloud board is loaded separately by
  /// [loadForUser] once the user signs in.
  Future<void> _load() async {
    final List<CommTile>? saved = await _storage.loadTiles();
    final bool? dark = await _storage.loadDarkMode();
    final ({int columns, int rows})? grid = await _storage.loadGrid();
    final ({bool enabled, int seconds})? scan = await _storage.loadScanning();
    final List<Utterance>? log = await _storage.loadUtterances();

    var changed = false;
    if (saved != null && saved.isNotEmpty) {
      _tiles = saved;
      changed = true;
    }
    if (dark != null) {
      _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
      changed = true;
    }
    if (grid != null) {
      _gridColumns = grid.columns.clamp(kMinGridAxis, kMaxGridAxis);
      _gridRows = grid.rows.clamp(kMinGridAxis, kMaxGridAxis);
      changed = true;
    }
    if (scan != null) {
      _scanningEnabled = scan.enabled;
      _scanSeconds = scan.seconds.clamp(kMinScanSeconds, kMaxScanSeconds);
      changed = true;
    }
    if (log != null && log.isNotEmpty) {
      _utterances
        ..clear()
        ..addAll(log);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Loads the signed-in user's board from Firebase. Call this after login,
  /// once the board service has the user's auth. If the account has no board
  /// yet, the current defaults are seeded up so the database shows data.
  Future<void> loadForUser() async {
    final FirebaseBoardService? firebase = _firebase;
    if (firebase == null || !firebase.hasAuth) return;
    try {
      final List<CommTile> cloud = await firebase.fetchTiles();
      if (cloud.isNotEmpty) {
        _tiles = cloud;
      } else {
        // New account — seed it with the default board.
        _tiles = List<CommTile>.of(kInitialTiles);
        unawaited(firebase.putBoard(_tiles).catchError((Object _) {}));
      }
      unawaited(_storage.saveTiles(_tiles));
      // Only now can a later empty read be trusted: the account has been
      // seen, and seeding (if it was needed) has been dispatched.
      _cloudLoaded = true;
      notifyListeners();
    } catch (_) {
      // Offline or unreachable — keep whatever is loaded locally.
    }

    // Layout and theme come down from the account too, because a controller
    // sets them from their own device.
    try {
      _applySettings(await firebase.fetchSettings());
    } catch (_) {
      // Keep the device's own settings.
    }

    // The usage history is a separate concern: a failure here must not cost
    // us the board we just loaded, so it gets its own guard.
    try {
      final List<Utterance> cloudLog = await firebase.fetchLog();
      if (cloudLog.isNotEmpty) {
        _utterances
          ..clear()
          ..addAll(cloudLog);
        unawaited(_storage.saveUtterances(_utterances));
        notifyListeners();
      }
    } catch (_) {
      // Keep the locally cached history.
    }
  }

  // ---------------------------------------------------------------------------
  // Live sync
  //
  // A guardian can edit this board from their own device, so the board cannot
  // be a one-shot load: without this, their changes would not appear until the
  // patient restarted the app.
  //
  // Firebase pushes changes over a REST event-stream, so where the platform
  // can hold that stream open the board updates as soon as the change lands —
  // no interval at all. The browser cannot (its HTTP client buffers a response
  // until it finishes), so web falls back to a short poll instead.
  // ---------------------------------------------------------------------------

  Timer? _syncTimer;
  Timer? _debounce;
  final List<StreamSubscription<String>> _watches =
      <StreamSubscription<String>>[];
  DateTime? _lastLocalEdit;

  /// Poll interval, used only where the event-stream is unavailable.
  static const Duration syncInterval = Duration(seconds: 2);

  /// A slow safety net that runs alongside the live stream, so a dropped or
  /// missed push cannot leave the board stale indefinitely.
  static const Duration _heartbeat = Duration(seconds: 30);

  /// A local edit is still travelling to the server for a moment; re-reading
  /// inside this window would briefly resurrect what the user just changed.
  static const Duration _quietAfterLocalEdit = Duration(seconds: 3);

  void startCloudSync() {
    final FirebaseBoardService? firebase = _firebase;
    if (firebase == null) return;
    stopCloudSync();

    if (FirebaseBoardService.supportsStreaming) {
      // Push: the board reacts as fast as the network delivers the event.
      _openWatch('tiles');
      _openWatch('settings');
      _syncTimer = Timer.periodic(_heartbeat, (_) => _syncFromCloud());
    } else {
      _syncTimer = Timer.periodic(syncInterval, (_) => _syncFromCloud());
    }
  }

  void _openWatch(String path) {
    final FirebaseBoardService? firebase = _firebase;
    if (firebase == null || !firebase.hasAuth) return;

    _watches.add(
      firebase.watch(path).listen(
        (_) => _scheduleSync(),
        // A dropped stream is normal on mobile networks; reopen rather than
        // silently falling back to nothing.
        onError: (Object _) => _reopenLater(path),
        onDone: () => _reopenLater(path),
        cancelOnError: true,
      ),
    );
  }

  void _reopenLater(String path) {
    if (_syncTimer == null) return; // Sync was stopped deliberately.
    Timer(const Duration(seconds: 3), () {
      if (_syncTimer == null) return;
      _openWatch(path);
    });
  }

  /// Two streams can fire for one change; coalesce them into a single read.
  void _scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 150),
      () => _syncFromCloud(),
    );
  }

  void stopCloudSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _debounce?.cancel();
    _debounce = null;
    for (final StreamSubscription<String> sub in _watches) {
      unawaited(sub.cancel());
    }
    _watches.clear();
  }

  Future<void> _syncFromCloud() async {
    final FirebaseBoardService? firebase = _firebase;
    if (firebase == null || !firebase.hasAuth) return;

    final DateTime? edited = _lastLocalEdit;
    if (edited != null &&
        DateTime.now().difference(edited) < _quietAfterLocalEdit) {
      return;
    }

    try {
      // Layout and theme first: a controller may have changed only those.
      _applySettings(await firebase.fetchSettings());

      final List<CommTile> cloud = await firebase.fetchTiles();

      // An empty result is only ambiguous before the first successful load:
      // until then it could equally mean "this account has no board yet" (and
      // [loadForUser] is about to seed one) as "the board is empty", and
      // wiping the on-screen board over that race would be unrecoverable.
      //
      // Afterwards it is authoritative. A non-2xx response throws, so an empty
      // list here came from a genuine success — the guardian really did delete
      // every tile, and the patient must see that rather than a stale board.
      if (cloud.isEmpty && !_cloudLoaded) return;
      if (_sameBoard(cloud, _tiles)) return;

      _tiles = cloud;
      unawaited(_storage.saveTiles(_tiles));
      notifyListeners();
    } catch (_) {
      // Offline — keep showing the board we have.
    }
  }

  /// Applies layout and theme received from the account. Returns true when
  /// anything actually changed, so callers can avoid a pointless rebuild.
  bool _applySettings(Map<String, dynamic> settings) {
    var changed = false;

    final Object? columns = settings['gridColumns'];
    final Object? rows = settings['gridRows'];
    final Object? dark = settings['darkMode'];

    if (columns is int) {
      final int next = columns.clamp(kMinGridAxis, kMaxGridAxis);
      if (next != _gridColumns) {
        _gridColumns = next;
        changed = true;
      }
    }
    if (rows is int) {
      final int next = rows.clamp(kMinGridAxis, kMaxGridAxis);
      if (next != _gridRows) {
        _gridRows = next;
        changed = true;
      }
    }
    if (dark is bool) {
      final ThemeMode next = dark ? ThemeMode.dark : ThemeMode.light;
      if (next != _themeMode) {
        _themeMode = next;
        changed = true;
      }
    }

    final Object? scanning = settings['scanningEnabled'];
    final Object? scanSecs = settings['scanSeconds'];
    if (scanning is bool && scanning != _scanningEnabled) {
      _scanningEnabled = scanning;
      changed = true;
    }
    if (scanSecs is int) {
      final int next = scanSecs.clamp(kMinScanSeconds, kMaxScanSeconds);
      if (next != _scanSeconds) {
        _scanSeconds = next;
        changed = true;
      }
    }

    if (changed) {
      unawaited(_storage.saveGrid(_gridColumns, _gridRows));
      unawaited(_storage.saveDarkMode(isDarkMode));
      unawaited(_storage.saveScanning(_scanningEnabled, _scanSeconds));
      notifyListeners();
    }
    return changed;
  }

  static bool _sameBoard(List<CommTile> a, List<CommTile> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (jsonEncode(a[i].toJson()) != jsonEncode(b[i].toJson())) return false;
    }
    return true;
  }

  /// Resets the board to the built-in defaults (used on logout) and clears the
  /// local cache so the next account starts clean.
  void resetToDefaults() {
    stopCloudSync();
    // The next account starts unverified again.
    _cloudLoaded = false;
    _tiles = List<CommTile>.of(kInitialTiles);
    // The usage history belongs to the account that just signed out, so it is
    // cleared with the board rather than bleeding into the next user's stats.
    _utterances.clear();
    unawaited(_storage.saveTiles(_tiles));
    unawaited(_storage.saveUtterances(_utterances));
    notifyListeners();
  }

  /// Fire-and-forget save of the current board to local storage. Also marks
  /// the moment, so the cloud poll does not read back a stale board while this
  /// change is still in flight.
  void _persist() {
    _lastLocalEdit = DateTime.now();
    unawaited(_storage.saveTiles(_tiles));
  }

  /// Runs a cloud write in the background, swallowing errors so a failed sync
  /// never breaks the UI (the change is already saved locally).
  void _cloud(Future<void>? Function() op) {
    final Future<void>? future = op();
    if (future != null) unawaited(future.catchError((Object _) {}));
  }

  List<CommTile> get tiles => List<CommTile>.unmodifiable(_tiles);
  EchoTab get activeTab => _activeTab;
  List<Utterance> get utterances => List<Utterance>.unmodifiable(_utterances);

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // ---------------------------------------------------------------------------
  // Board layout
  // ---------------------------------------------------------------------------

  int get gridColumns => _gridColumns;
  int get gridRows => _gridRows;

  /// How many tiles fill a single page of the board.
  int get tilesPerPage => _gridColumns * _gridRows;

  /// Total pages the current board spans. Always at least one, so the Speak
  /// view has an (empty) page to render before any tiles exist.
  int get pageCount => _tiles.isEmpty
      ? 1
      : ((_tiles.length + tilesPerPage - 1) ~/ tilesPerPage);

  /// The tiles belonging to [page] (zero-based), in board order.
  List<CommTile> tilesForPage(int page) {
    final int start = page * tilesPerPage;
    if (start >= _tiles.length) return const <CommTile>[];
    final int end = (start + tilesPerPage).clamp(0, _tiles.length);
    return List<CommTile>.unmodifiable(_tiles.sublist(start, end));
  }

  // ---------------------------------------------------------------------------
  // Switch scanning
  // ---------------------------------------------------------------------------

  bool get scanningEnabled => _scanningEnabled;
  int get scanSeconds => _scanSeconds;
  Duration get scanInterval => Duration(seconds: _scanSeconds);

  void setScanning({bool? enabled, int? seconds}) {
    final bool nextEnabled = enabled ?? _scanningEnabled;
    final int nextSeconds = (seconds ?? _scanSeconds).clamp(
      kMinScanSeconds,
      kMaxScanSeconds,
    );
    if (nextEnabled == _scanningEnabled && nextSeconds == _scanSeconds) return;

    _scanningEnabled = nextEnabled;
    _scanSeconds = nextSeconds;
    unawaited(_storage.saveScanning(_scanningEnabled, _scanSeconds));
    _cloud(
      () => _firebase?.patchSettings(
        scanningEnabled: _scanningEnabled,
        scanSeconds: _scanSeconds,
      ),
    );
    notifyListeners();
  }

  /// Sets the board layout. Values outside [kMinGridAxis]..[kMaxGridAxis] are
  /// clamped rather than rejected, so callers can step freely.
  void setGrid({int? columns, int? rows}) {
    final int nextColumns = (columns ?? _gridColumns).clamp(
      kMinGridAxis,
      kMaxGridAxis,
    );
    final int nextRows = (rows ?? _gridRows).clamp(kMinGridAxis, kMaxGridAxis);
    if (nextColumns == _gridColumns && nextRows == _gridRows) return;

    _gridColumns = nextColumns;
    _gridRows = nextRows;
    unawaited(_storage.saveGrid(_gridColumns, _gridRows));
    _cloud(
      () => _firebase?.patchSettings(
        gridColumns: _gridColumns,
        gridRows: _gridRows,
      ),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Caregiver stats — all derived from the persisted utterance log.
  // ---------------------------------------------------------------------------

  /// All caregiver figures come from one place, so the patient's device and a
  /// controller's console can never disagree about them.
  UsageStats get stats => UsageStats(_utterances);

  int get spokenToday => stats.today;
  int get dayStreak => stats.dayStreak;
  List<({String day, int count})> get weeklySeries => stats.weekly;

  void setDarkMode(bool value) {
    final ThemeMode next = value ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == next) return;
    _themeMode = next;
    unawaited(_storage.saveDarkMode(value));
    _cloud(() => _firebase?.patchSettings(darkMode: value));
    notifyListeners();
  }

  set tiles(List<CommTile> value) {
    _tiles = List<CommTile>.of(value);
    _persist();
    notifyListeners();
  }

  void setActiveTab(EchoTab tab) {
    if (_activeTab == tab) return;
    _activeTab = tab;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Board editing (CRUD)
  //
  // Every mutation replaces the list so listeners rebuild predictably, then
  // calls _persist() to save the board to local storage — so changes survive
  // an app restart.
  // ---------------------------------------------------------------------------

  int _idCounter = 0;

  String _newId() {
    // Timestamp keeps ids unique across the (future) persisted board; the
    // counter breaks ties when two tiles are added in the same microsecond.
    return 'tile_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
  }

  CommTile addTile({
    required String label,
    required String ttsPhrase,
    required IconData icon,
    required String colorTheme,
    String? imageUrl,
  }) {
    final CommTile tile = CommTile(
      id: _newId(),
      label: label,
      ttsPhrase: ttsPhrase,
      icon: icon,
      colorTheme: colorTheme,
      imageUrl: imageUrl,
    );
    _tiles = <CommTile>[..._tiles, tile];
    _persist();
    _cloud(() => _firebase?.putTile(tile)); // CREATE — HTTP PUT
    notifyListeners();
    return tile;
  }

  void updateTile(
    String id, {
    String? label,
    String? ttsPhrase,
    IconData? icon,
    String? colorTheme,
    // Defaults to the sentinel so an omitted argument leaves the pictogram
    // untouched; pass null explicitly to clear it back to the icon.
    Object? imageUrl = CommTile.keep,
  }) {
    _tiles = <CommTile>[
      for (final CommTile t in _tiles)
        if (t.id == id)
          t.copyWith(
            label: label,
            ttsPhrase: ttsPhrase,
            icon: icon,
            colorTheme: colorTheme,
            imageUrl: imageUrl,
          )
        else
          t,
    ];
    _persist();
    // UPDATE — HTTP PATCH the changed tile.
    for (final CommTile t in _tiles) {
      if (t.id == id) {
        _cloud(() => _firebase?.patchTile(t));
        break;
      }
    }
    notifyListeners();
  }

  void removeTile(String id) {
    _tiles = _tiles.where((CommTile t) => t.id != id).toList();
    _persist();
    _cloud(() => _firebase?.deleteTile(id)); // DELETE — HTTP DELETE
    notifyListeners();
  }

  /// Stands in for the Text-to-Speech engine.
  ///
  /// Wiring this to `flutter_tts` later means replacing the body of this one
  /// method — nothing in the widget layer needs to change.
  void speak(CommTile tile) {
    debugPrint('[Echo TTS] Speaking: "${tile.ttsPhrase}"');
    // Produce real spoken audio through the platform TTS engine (null in tests).
    _tts?.speak(tile.ttsPhrase);

    _utterances.add(
      Utterance(tileId: tile.id, label: tile.label, spokenAt: DateTime.now()),
    );
    // Cache the history locally so the caregiver dashboard survives a restart.
    unawaited(_storage.saveUtterances(_utterances));
    // LOG — HTTP POST an event to the usage log (Firebase generates the key).
    _cloud(() => _firebase?.logSpoken(tile.id, tile.label));
    notifyListeners();
  }

  /// Fires the emergency.
  ///
  /// The alarm on this device is the primary signal and happens first; raising
  /// the SOS record is the remote echo that reaches any paired guardians. A
  /// failure to reach the network must never mute the local alarm, so the
  /// cloud write is fire-and-forget like every other.
  void raiseEmergency() {
    speak(kEmergencyTile);
    _cloud(() => _firebase?.raiseSos(kEmergencyTile.label));
  }

  @override
  void dispose() {
    stopCloudSync();
    super.dispose();
  }

  /// The tile spoken most often, or null before anything has been said.
  CommTile? get mostUsedTile => stats.mostUsedTile(_tiles);
}

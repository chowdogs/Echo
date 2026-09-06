import 'dart:async';

import 'package:flutter/material.dart';

import '../models/comm_tile.dart';
import '../services/board_storage.dart';
import '../services/firebase_board_service.dart';
import '../services/tts_service.dart';

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

  /// Loads the board and theme from local storage at startup (instant and
  /// offline-safe). The per-account cloud board is loaded separately by
  /// [loadForUser] once the user signs in.
  Future<void> _load() async {
    final List<CommTile>? saved = await _storage.loadTiles();
    final bool? dark = await _storage.loadDarkMode();

    var changed = false;
    if (saved != null && saved.isNotEmpty) {
      _tiles = saved;
      changed = true;
    }
    if (dark != null) {
      _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
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
      notifyListeners();
    } catch (_) {
      // Offline or unreachable — keep whatever is loaded locally.
    }
  }

  /// Resets the board to the built-in defaults (used on logout) and clears the
  /// local cache so the next account starts clean.
  void resetToDefaults() {
    _tiles = List<CommTile>.of(kInitialTiles);
    unawaited(_storage.saveTiles(_tiles));
    notifyListeners();
  }

  /// Fire-and-forget save of the current board to local storage.
  void _persist() {
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

  void setDarkMode(bool value) {
    final ThemeMode next = value ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == next) return;
    _themeMode = next;
    unawaited(_storage.saveDarkMode(value));
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
    // LOG — HTTP POST an event to the usage log (Firebase generates the key).
    _cloud(() => _firebase?.logSpoken(tile.id, tile.label));
    notifyListeners();
  }

  /// The tile spoken most often, or null before anything has been said.
  CommTile? get mostUsedTile {
    if (_utterances.isEmpty) return null;

    final Map<String, int> counts = <String, int>{};
    for (final Utterance utterance in _utterances) {
      counts[utterance.tileId] = (counts[utterance.tileId] ?? 0) + 1;
    }

    final String topId = counts.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;

    for (final CommTile tile in _tiles) {
      if (tile.id == topId) return tile;
    }
    return null;
  }
}

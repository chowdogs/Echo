import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import '../models/comm_tile.dart';

/// Persists the board (and the theme choice) to the device's local storage
/// using `shared_preferences`.
///
/// This is the app's single seam to on-device storage: [TileState] calls
/// [saveTiles] after every create/update/delete and [loadTiles] once at
/// startup. Every method swallows storage errors and degrades gracefully — if
/// the platform store is unavailable, the app simply falls back to its
/// in-memory defaults instead of crashing.
class BoardStorage {
  static const String _tilesKey = 'echo.board.tiles.v1';
  static const String _themeKey = 'echo.settings.darkMode.v1';
  static const String _sessionKey = 'echo.auth.session.v1';
  static const String _gridKey = 'echo.board.grid.v1';
  static const String _logKey = 'echo.board.log.v1';

  /// Most recent utterances kept on device. Enough for the caregiver
  /// dashboard's week view without letting the cache grow without bound.
  static const int _maxStoredUtterances = 500;

  /// Writes the whole board as a JSON string.
  Future<void> saveTiles(List<CommTile> tiles) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(
        tiles.map((CommTile t) => t.toJson()).toList(),
      );
      await prefs.setString(_tilesKey, encoded);
    } catch (_) {
      // Storage unavailable — nothing else to do; the in-memory board stands.
    }
  }

  /// Reads the saved board, or null if nothing is stored yet (fresh install)
  /// or the data can't be parsed.
  Future<List<CommTile>?> loadTiles() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_tilesKey);
      if (raw == null) return null;

      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return null;

      final List<CommTile> tiles = decoded
          .whereType<Map<String, dynamic>>()
          .map(CommTile.fromJson)
          .whereType<CommTile>()
          .toList();
      return tiles.isEmpty ? null : tiles;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(AuthSession session) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    } catch (_) {
      // ignore
    }
  }

  Future<AuthSession?> loadSession() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_sessionKey);
      if (raw == null) return null;
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AuthSession.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {
      // ignore
    }
  }

  /// Saves the board layout (tiles per page = columns x rows).
  Future<void> saveGrid(int columns, int rows) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_gridKey, '$columns:$rows');
    } catch (_) {
      // ignore
    }
  }

  /// Returns the saved layout, or null if the user has not chosen one.
  Future<({int columns, int rows})?> loadGrid() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_gridKey);
      if (raw == null) return null;

      final List<String> parts = raw.split(':');
      if (parts.length != 2) return null;
      final int? columns = int.tryParse(parts[0]);
      final int? rows = int.tryParse(parts[1]);
      if (columns == null || rows == null) return null;
      return (columns: columns, rows: rows);
    } catch (_) {
      return null;
    }
  }

  /// Persists the usage log so the caregiver dashboard survives a restart.
  /// Only the most recent [_maxStoredUtterances] entries are kept.
  Future<void> saveUtterances(List<Utterance> utterances) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Utterance> trimmed = utterances.length > _maxStoredUtterances
          ? utterances.sublist(utterances.length - _maxStoredUtterances)
          : utterances;
      final String encoded = jsonEncode(
        trimmed.map((Utterance u) => u.toJson()).toList(),
      );
      await prefs.setString(_logKey, encoded);
    } catch (_) {
      // ignore
    }
  }

  /// Reads the stored usage log, oldest first. Null when nothing is saved.
  Future<List<Utterance>?> loadUtterances() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_logKey);
      if (raw == null) return null;

      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return null;

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Utterance.fromJson)
          .whereType<Utterance>()
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDarkMode(bool isDark) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, isDark);
    } catch (_) {
      // ignore
    }
  }

  /// Returns the saved dark-mode preference, or null if none is stored.
  Future<bool?> loadDarkMode() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_themeKey);
    } catch (_) {
      return null;
    }
  }
}

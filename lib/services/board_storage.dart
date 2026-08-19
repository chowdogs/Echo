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

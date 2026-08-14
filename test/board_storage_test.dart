import 'package:echo/models/comm_tile.dart';
import 'package:echo/services/board_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommTile JSON', () {
    test('toJson / fromJson round-trips every field', () {
      const CommTile tile = CommTile(
        id: 'x1',
        label: 'Water',
        ttsPhrase: 'I want water.',
        icon: Icons.local_drink_rounded,
        colorTheme: 'sky',
        imageUrl: 'https://static.arasaac.org/pictograms/2248/2248_300.png',
      );

      final CommTile? restored = CommTile.fromJson(tile.toJson());

      expect(restored, isNotNull);
      expect(restored!.id, 'x1');
      expect(restored.label, 'Water');
      expect(restored.ttsPhrase, 'I want water.');
      expect(restored.icon.codePoint, Icons.local_drink_rounded.codePoint);
      expect(restored.colorTheme, 'sky');
      expect(restored.imageUrl, tile.imageUrl);
    });

    test('fromJson rejects a malformed record', () {
      expect(CommTile.fromJson(<String, dynamic>{'id': 'x'}), isNull);
    });
  });

  group('BoardStorage (local storage)', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('returns null before anything has been saved', () async {
      expect(await BoardStorage().loadTiles(), isNull);
    });

    test('saves a board and reads it back', () async {
      final BoardStorage storage = BoardStorage();
      final List<CommTile> board = <CommTile>[
        const CommTile(
          id: 'cold',
          label: 'Cold',
          ttsPhrase: 'I am cold.',
          icon: Icons.ac_unit_rounded,
          colorTheme: 'sky',
        ),
      ];

      await storage.saveTiles(board);
      final List<CommTile>? loaded = await storage.loadTiles();

      expect(loaded, isNotNull);
      expect(loaded!.single.label, 'Cold');
      expect(loaded.single.colorTheme, 'sky');
    });

    test('remembers the dark-mode preference', () async {
      final BoardStorage storage = BoardStorage();
      expect(await storage.loadDarkMode(), isNull);

      await storage.saveDarkMode(true);
      expect(await storage.loadDarkMode(), isTrue);
    });
  });
}

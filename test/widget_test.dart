import 'package:echo/main.dart';
import 'package:echo/models/comm_tile.dart';
import 'package:echo/state/tile_state.dart';
import 'package:echo/widgets/tile_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the app and taps through the landing screen into the main shell,
/// leaving the Speak view active. Most widget tests start from here.
Future<void> pumpToShell(WidgetTester tester) async {
  await tester.pumpWidget(const EchoApp());
  // Let the landing entrance animation finish: while it is mid-fade the CTA
  // sits under an Opacity(0), which drops it from the semantics tree.
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('Get started'));
  await tester.pumpAndSettle();
}

void main() {
  group('TileState', () {
    test('speak records an utterance for the tapped tile', () {
      final TileState state = TileState();
      expect(state.utterances, isEmpty);

      state.speak(kInitialTiles.first);

      expect(state.utterances, hasLength(1));
      expect(state.utterances.single.tileId, kInitialTiles.first.id);
    });

    test('mostUsedTile returns the tile spoken most often', () {
      final TileState state = TileState();
      expect(state.mostUsedTile, isNull);

      state.speak(kInitialTiles[1]);
      state.speak(kInitialTiles[0]);
      state.speak(kInitialTiles[0]);

      expect(state.mostUsedTile?.id, kInitialTiles[0].id);
    });

    test('exposed collections are unmodifiable', () {
      final TileState state = TileState();

      expect(() => state.tiles.add(kEmergencyTile), throwsUnsupportedError);
    });

    test('addTile appends a tile with a unique id', () {
      final TileState state = TileState();
      final int before = state.tiles.length;

      final CommTile a = state.addTile(
        label: 'Water',
        ttsPhrase: 'I want water.',
        icon: Icons.water_drop_rounded,
        colorTheme: 'sky',
      );
      final CommTile b = state.addTile(
        label: 'Music',
        ttsPhrase: 'I want music.',
        icon: Icons.music_note_rounded,
        colorTheme: 'violet',
      );

      expect(state.tiles.length, before + 2);
      expect(state.tiles.last.label, 'Music');
      expect(a.id, isNot(b.id));
    });

    test('updateTile changes only the targeted tile', () {
      final TileState state = TileState();
      final String id = state.tiles.first.id;

      state.updateTile(id, label: 'Renamed', ttsPhrase: 'New phrase.');

      final CommTile updated = state.tiles.firstWhere((t) => t.id == id);
      expect(updated.label, 'Renamed');
      expect(updated.ttsPhrase, 'New phrase.');
      // A sibling is untouched.
      expect(state.tiles[1].label, kInitialTiles[1].label);
    });

    test('removeTile drops the tile', () {
      final TileState state = TileState();
      final String id = state.tiles.first.id;
      final int before = state.tiles.length;

      state.removeTile(id);

      expect(state.tiles.length, before - 1);
      expect(state.tiles.any((t) => t.id == id), isFalse);
    });
  });

  group('Echo app', () {
    testWidgets('opens on the landing screen, not the board', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EchoApp());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Get started'), findsOneWidget);
      expect(find.byType(TileButton), findsNothing);
    });

    testWidgets('Get Started reveals the nine starter tiles', (
      WidgetTester tester,
    ) async {
      await pumpToShell(tester);

      expect(find.byType(TileButton), findsNWidgets(9));
      expect(find.text('Hungry'), findsOneWidget);
    });

    testWidgets('the Edit control is gone', (WidgetTester tester) async {
      await pumpToShell(tester);

      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('bottom nav reaches all three destinations', (
      WidgetTester tester,
    ) async {
      await pumpToShell(tester);

      await tester.tap(find.bySemanticsLabel('Emergency'));
      await tester.pumpAndSettle();
      expect(find.text('HOLD FOR HELP'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Dark mode'), findsOneWidget);

      // Stats is no longer a nav tab — it is reached from Settings.
      expect(find.bySemanticsLabel('Stats'), findsNothing);
    });

    testWidgets('Settings opens the Stats page', (WidgetTester tester) async {
      await pumpToShell(tester);

      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();

      expect(find.text('Communications today'), findsOneWidget);
    });

    // The 800x600 default test surface is not a phone. These sizes are the
    // real targets, and an overflow at any of them is a shipped layout bug —
    // the framework turns one into a test failure, so simply rendering each
    // view at each size is the assertion.
    for (final (String name, Size size) in <(String, Size)>[
      ('small phone', Size(320, 568)),
      ('modern phone', Size(390, 844)),
      ('tablet', Size(834, 1112)),
    ]) {
      testWidgets('lays out every view on a $name without overflow', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpToShell(tester);
        expect(find.byType(TileButton), findsNWidgets(9));

        await tester.tap(find.bySemanticsLabel('Emergency'));
        await tester.pumpAndSettle();
        expect(find.text('HOLD FOR HELP'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Settings'));
        await tester.pumpAndSettle();
        expect(find.text('Dark mode'), findsOneWidget);

        // The Stats page, reached from Settings, lays out too. Scroll the row
        // into view first — on a short screen it sits below the fold.
        await tester.scrollUntilVisible(find.text('Stats'), 120);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Stats'));
        await tester.pumpAndSettle();
        expect(find.text('Communications today'), findsOneWidget);
      });
    }

    testWidgets('starts in light mode and the Settings toggle flips it', (
      WidgetTester tester,
    ) async {
      await pumpToShell(tester);

      // Default is light.
      MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);

      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Dark mode'), findsOneWidget);

      // The Appearance group is first, so its switch is the first one.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      app = tester.widget(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });

    testWidgets('Settings opens the board editor and can add a tile', (
      WidgetTester tester,
    ) async {
      await pumpToShell(tester);

      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit communication board'));
      await tester.pumpAndSettle();

      expect(find.text('Edit board'), findsOneWidget);
      expect(find.text('9 tiles'), findsOneWidget);

      // Open the add sheet, name the tile, and save.
      await tester.tap(find.text('Add tile'));
      await tester.pumpAndSettle();

      expect(find.text('New tile'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Cold');
      // Let the label listener re-enable the save button before tapping it.
      await tester.pumpAndSettle();
      // The sheet is taller than the test surface; scroll the button into
      // view. Target it by key so the page's FAB (also labelled 'Add tile')
      // can't be hit by accident.
      final Finder save = find.byKey(const Key('tile-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      // The board grew by one, reflected live in the header count.
      expect(find.text('10 tiles'), findsOneWidget);
    });

    testWidgets('board editor can delete a tile', (WidgetTester tester) async {
      await pumpToShell(tester);

      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit communication board'));
      await tester.pumpAndSettle();
      expect(find.text('9 tiles'), findsOneWidget);

      // Remove the first tile, then confirm in the dialog.
      await tester.tap(find.byTooltip('Remove Hungry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('8 tiles'), findsOneWidget);
    });

    testWidgets('tapping a tile increments the dashboard count', (
      WidgetTester tester,
    ) async {
      await pumpToShell(tester);

      await tester.tap(find.byType(TileButton).first);
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();

      // The headline stat is live, so one tap must show as one communication.
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('SOS activates only after a full 2-second hold', (
      WidgetTester tester,
    ) async {
      await pumpToShell(tester);
      await tester.tap(find.bySemanticsLabel('Emergency'));
      await tester.pumpAndSettle();

      final Finder sos = find.bySemanticsLabel(
        'Emergency. Hold for two seconds to send an alert.',
      );

      // A short hold must NOT activate.
      TestGesture gesture = await tester.startGesture(tester.getCenter(sos));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('KEEP HOLDING'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('SENT'), findsNothing);
      expect(find.text('HOLD FOR HELP'), findsOneWidget);

      // A full hold past 2 seconds activates.
      gesture = await tester.startGesture(tester.getCenter(sos));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pump();
      expect(find.text('SENT'), findsOneWidget);
      await gesture.up();
      await tester.pump();
    });
  });
}

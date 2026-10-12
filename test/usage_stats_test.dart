import 'package:echo/models/comm_tile.dart';
import 'package:echo/state/usage_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the figures behind the caregiver dashboard (TS-12).
///
/// These are pure functions over a list of utterances, so they can be proven
/// exactly rather than eyeballed on screen — which matters, because a wrong
/// "communications today" is the kind of error that looks plausible and would
/// quietly mislead someone making care decisions.
void main() {
  // Anchored to "now" rather than a fixed date, so the suite does not start
  // failing the moment the calendar moves.
  final DateTime now = DateTime.now();

  Utterance at(DateTime when, {String tileId = 'hungry'}) =>
      Utterance(tileId: tileId, label: tileId, spokenAt: when);

  /// Midday on the day [daysAgo] before today — midday avoids a test near
  /// midnight tipping into the wrong day.
  DateTime daysAgo(int days) {
    final DateTime d = now.subtract(Duration(days: days));
    return DateTime(d.year, d.month, d.day, 12);
  }

  const List<CommTile> tiles = <CommTile>[
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
  ];

  group('UsageStats.today', () {
    test('counts only utterances spoken today', () {
      final UsageStats stats = UsageStats(<Utterance>[
        at(daysAgo(0)),
        at(daysAgo(0)),
        at(daysAgo(1)),
        at(daysAgo(5)),
      ]);
      expect(stats.today, 2);
    });

    test('is zero for an empty log', () {
      expect(const UsageStats(<Utterance>[]).today, 0);
    });
  });

  group('UsageStats.dayStreak', () {
    test('counts consecutive days ending today', () {
      final UsageStats stats = UsageStats(<Utterance>[
        at(daysAgo(0)),
        at(daysAgo(1)),
        at(daysAgo(2)),
      ]);
      expect(stats.dayStreak, 3);
    });

    test('stops at the first missed day', () {
      final UsageStats stats = UsageStats(<Utterance>[
        at(daysAgo(0)),
        at(daysAgo(1)),
        // Nothing on day 2 — the run ends here.
        at(daysAgo(3)),
        at(daysAgo(4)),
      ]);
      expect(stats.dayStreak, 2);
    });

    test('is zero when nothing was spoken today, even with past activity', () {
      final UsageStats stats = UsageStats(<Utterance>[
        at(daysAgo(1)),
        at(daysAgo(2)),
      ]);
      expect(stats.dayStreak, 0);
    });

    test('is zero for an empty log', () {
      expect(const UsageStats(<Utterance>[]).dayStreak, 0);
    });
  });

  group('UsageStats.weekly', () {
    test('returns seven days, oldest first, ending today', () {
      final UsageStats stats = UsageStats(<Utterance>[at(daysAgo(0))]);
      final List<({String day, int count})> series = stats.weekly;

      expect(series.length, 7);
      // The last bucket is today, and holds the one utterance.
      expect(series.last.count, 1);
    });

    test('buckets each utterance into the right day', () {
      final UsageStats stats = UsageStats(<Utterance>[
        at(daysAgo(0)),
        at(daysAgo(0)),
        at(daysAgo(2)),
      ]);
      final List<({String day, int count})> series = stats.weekly;

      expect(series.last.count, 2, reason: 'today');
      expect(series[4].count, 1, reason: 'two days ago');
      expect(series[5].count, 0, reason: 'yesterday was quiet');
    });

    test('ignores anything older than the window', () {
      final UsageStats stats = UsageStats(<Utterance>[at(daysAgo(30))]);
      final int total = stats.weekly.fold(
        0,
        (int sum, ({String day, int count}) e) => sum + e.count,
      );
      expect(total, 0);
    });
  });

  group('UsageStats.mostUsedTile', () {
    test('returns the tile spoken most often', () {
      final UsageStats stats = UsageStats(<Utterance>[
        at(daysAgo(0), tileId: 'thirsty'),
        at(daysAgo(0), tileId: 'hungry'),
        at(daysAgo(1), tileId: 'hungry'),
      ]);
      expect(stats.mostUsedTile(tiles)?.id, 'hungry');
    });

    test('is null before anything has been said', () {
      expect(const UsageStats(<Utterance>[]).mostUsedTile(tiles), isNull);
    });

    test('is null when the winning tile has since been deleted', () {
      final UsageStats stats = UsageStats(<Utterance>[
        at(daysAgo(0), tileId: 'removed-tile'),
      ]);
      expect(stats.mostUsedTile(tiles), isNull);
    });
  });

  group('UsageStats.recent', () {
    test('returns newest first, capped at the limit', () {
      final UsageStats stats = UsageStats(<Utterance>[
        at(daysAgo(3), tileId: 'oldest'),
        at(daysAgo(2), tileId: 'middle'),
        at(daysAgo(1), tileId: 'newest'),
      ]);

      final List<Utterance> recent = stats.recent(2);
      expect(recent.length, 2);
      expect(recent.first.tileId, 'newest');
    });
  });
}

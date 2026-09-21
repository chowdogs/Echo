import '../models/comm_tile.dart';

/// Caregiver figures derived from a usage log.
///
/// Pure and self-contained so the same numbers are produced whether they are
/// read on the patient's own device or pulled from their account into a
/// controller's console — a guardian and a patient must never see a different
/// "today".
class UsageStats {
  const UsageStats(this.utterances);

  final List<Utterance> utterances;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// Utterances spoken today — the dashboard's headline number.
  int get today {
    final DateTime now = DateTime.now();
    return utterances.where((Utterance u) => _sameDay(u.spokenAt, now)).length;
  }

  /// Consecutive days up to today with at least one utterance. Zero when
  /// nothing has been said today, because the streak is already broken.
  int get dayStreak {
    if (utterances.isEmpty) return 0;

    final Set<String> days = utterances
        .map((Utterance u) => _dayKey(u.spokenAt))
        .toSet();

    var streak = 0;
    DateTime cursor = DateTime.now();
    while (days.contains(_dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// The last seven days, oldest first, for the bar chart.
  List<({String day, int count})> get weekly {
    const List<String> labels = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final DateTime today = DateTime.now();

    return List<({String day, int count})>.generate(7, (int i) {
      final DateTime day = today.subtract(Duration(days: 6 - i));
      final int count = utterances
          .where((Utterance u) => _sameDay(u.spokenAt, day))
          .length;
      return (day: labels[day.weekday - 1], count: count);
    });
  }

  /// The tile spoken most often, resolved against [tiles]. Null before
  /// anything has been said, or if that tile has since been deleted.
  CommTile? mostUsedTile(List<CommTile> tiles) {
    if (utterances.isEmpty) return null;

    final Map<String, int> counts = <String, int>{};
    for (final Utterance u in utterances) {
      counts[u.tileId] = (counts[u.tileId] ?? 0) + 1;
    }

    final String topId = counts.entries
        .reduce((MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value > a.value ? b : a)
        .key;

    for (final CommTile tile in tiles) {
      if (tile.id == topId) return tile;
    }
    return null;
  }

  /// Most recent first, capped at [limit] — the activity feed.
  List<Utterance> recent([int limit = 5]) =>
      utterances.reversed.take(limit).toList();
}

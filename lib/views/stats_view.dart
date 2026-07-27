import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/comm_tile.dart';
import '../state/tile_state.dart';
import '../theme/app_theme.dart';
import '../theme/tile_themes.dart';
import '../widgets/sub_page_header.dart';

/// Placeholder weekly series. Wired to real data once utterances persist
/// across sessions; the shape here matches what that query will return.
const List<({String day, int count})> _weeklyPlaceholder =
    <({String day, int count})>[
      (day: 'Mon', count: 18),
      (day: 'Tue', count: 24),
      (day: 'Wed', count: 12),
      (day: 'Thu', count: 31),
      (day: 'Fri', count: 27),
      (day: 'Sat', count: 9),
      (day: 'Sun', count: 15),
    ];

/// Caregiver dashboard, pushed as a page from Settings → Stats.
///
/// The headline number is live — it counts what the current session actually
/// spoke. Everything below it is structural placeholder awaiting persistence.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: const Column(
        children: <Widget>[
          SubPageHeader(
            title: 'Stats',
            subtitle: 'A quiet overview for caregivers',
          ),
          Expanded(child: _StatsBody()),
        ],
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody();

  @override
  Widget build(BuildContext context) {
    final TileState state = context.watch<TileState>();
    final CommTile? topTile = state.mostUsedTile;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: <Widget>[
        _HeroStat(count: state.utterances.length),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(child: _MostUsedCard(tile: topTile)),
            const SizedBox(width: 12),
            const Expanded(
              child: _MiniStat(
                icon: Icons.local_fire_department_rounded,
                label: 'Day streak',
                value: '—',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _WeeklyChart(),
        const SizedBox(height: 12),
        _RecentActivity(utterances: state.utterances),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return _Card(
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.forum_rounded, color: c.accent, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Communications today',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 38,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MostUsedCard extends StatelessWidget {
  const _MostUsedCard({required this.tile});

  final CommTile? tile;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final Color accent = tile == null
        ? c.muted
        : tileAccentFor(tile!.colorTheme);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Most used',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  tile?.icon ?? Icons.remove_rounded,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tile?.label ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: c.muted, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Weekly bar chart.
///
/// Single series, so one hue and no legend — the heading names what the bars
/// are. Values sit directly above each bar rather than behind a tooltip, which
/// suits a glanceable caregiver summary.
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart();

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final int maxCount = _weeklyPlaceholder
        .map((({String day, int count}) e) => e.count)
        .reduce((int a, int b) => a > b ? a : b);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Flexible(
                child: Text(
                  'This week',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Sample data',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 11, color: c.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _weeklyPlaceholder.map((({String day, int count}) e) {
                final bool isPeak = e.count == maxCount;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          '${e.count}',
                          style: TextStyle(
                            fontSize: 10,
                            color: c.muted,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Reserve room for the label and value text so the
                        // bars share one baseline regardless of height.
                        Expanded(
                          child: FractionallySizedBox(
                            alignment: Alignment.bottomCenter,
                            heightFactor: e.count / maxCount,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: <Color>[
                                    c.accent,
                                    c.accent.withValues(
                                      alpha: isPeak ? 0.85 : 0.45,
                                    ),
                                  ],
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          e.day,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.utterances});

  final List<Utterance> utterances;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final List<Utterance> recent = utterances.reversed.take(5).toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Recent activity',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          if (recent.isEmpty)
            Text(
              'No communications yet. Tiles tapped in the Speak view will '
              'appear here.',
              style: TextStyle(fontSize: 13, height: 1.5, color: c.muted),
            )
          else
            ...recent.map((Utterance utterance) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        utterance.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      TimeOfDay.fromDateTime(
                        utterance.spokenAt,
                      ).format(context),
                      style: TextStyle(
                        fontSize: 12,
                        color: c.muted,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/tile_state.dart';
import '../theme/app_theme.dart';
import '../widgets/section_intro.dart';
import 'board_editor_page.dart';
import 'stats_view.dart';

/// Settings.
///
/// Appearance is real — the dark-mode switch drives the app theme through
/// [TileState]. The other controls hold local state so they feel real, but do
/// not persist yet; each is the seam a real preference store will slot into.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  double _speechRate = 0.5;
  double _pitch = 1.0;
  bool _largeText = false;
  bool _reduceMotion = false;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final bool isDark = context.select<TileState, bool>((s) => s.isDarkMode);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: <Widget>[
        const SectionIntro(
          title: 'Settings',
          subtitle: 'Tune how Echo speaks and looks',
        ),
        const SizedBox(height: 20),
        _Group(
          title: 'Appearance',
          children: <Widget>[
            _SwitchRow(
              icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              label: 'Dark mode',
              subtitle: isDark ? 'Deep slate theme' : 'Light theme (default)',
              value: isDark,
              onChanged: (bool v) => context.read<TileState>().setDarkMode(v),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Group(
          title: 'Board',
          children: <Widget>[
            _NavRow(
              icon: Icons.dashboard_customize_rounded,
              label: 'Edit communication board',
              subtitle: 'Add, rename, or remove tiles',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BoardEditorPage(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Group(
          title: 'Insights',
          children: <Widget>[
            _NavRow(
              icon: Icons.insights_rounded,
              label: 'Stats',
              subtitle: 'Daily communications & recent activity',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const StatsPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Group(
          title: 'Voice',
          children: <Widget>[
            _SliderRow(
              icon: Icons.speed_rounded,
              label: 'Speech rate',
              value: _speechRate,
              onChanged: (double v) => setState(() => _speechRate = v),
            ),
            const _Divider(),
            _SliderRow(
              icon: Icons.graphic_eq_rounded,
              label: 'Pitch',
              value: _pitch,
              min: 0.5,
              max: 2.0,
              onChanged: (double v) => setState(() => _pitch = v),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Group(
          title: 'Display',
          children: <Widget>[
            _SwitchRow(
              icon: Icons.text_fields_rounded,
              label: 'Larger tile text',
              subtitle: 'Increase label size across the board',
              value: _largeText,
              onChanged: (bool v) => setState(() => _largeText = v),
            ),
            const _Divider(),
            _SwitchRow(
              icon: Icons.motion_photos_paused_rounded,
              label: 'Reduce motion',
              subtitle: 'Calm the emergency pulse and transitions',
              value: _reduceMotion,
              onChanged: (bool v) => setState(() => _reduceMotion = v),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Group(
          title: 'About',
          children: const <Widget>[
            _InfoRow(
              icon: Icons.info_outline_rounded,
              label: 'Version',
              value: '0.1.0',
            ),
            _Divider(),
            _InfoRow(
              icon: Icons.favorite_outline_rounded,
              label: 'Made for',
              value: 'Every voice',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Voice and display preferences are not saved yet in this build.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: c.muted),
          ),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: c.muted,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: EchoColors.of(context).border,
      indent: 16,
      endIndent: 16,
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 20, color: c.accent),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
  });

  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _RowIcon(icon),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: c.accent,
              inactiveTrackColor: c.surfaceHigh,
              thumbColor: c.accent,
              overlayColor: c.accent.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          _RowIcon(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.5, color: c.muted),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: c.accent,
            inactiveTrackColor: c.surfaceHigh,
            inactiveThumbColor: c.muted,
          ),
        ],
      ),
    );
  }
}

/// A tappable settings row that leads somewhere, marked with a chevron.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            _RowIcon(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.5, color: c.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.muted),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          _RowIcon(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          Text(value, style: TextStyle(fontSize: 14, color: c.muted)),
        ],
      ),
    );
  }
}

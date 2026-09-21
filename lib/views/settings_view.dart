import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../state/tile_state.dart';
import '../theme/app_theme.dart';
import '../widgets/section_intro.dart';
import 'board_editor_page.dart';
import 'patient_qr_page.dart';
import 'patients_page.dart';
import 'stats_view.dart';

/// Settings.
///
/// Every control here does something real and is persisted. Anything that
/// could only be mocked was removed rather than left as a dead switch — a
/// caregiver has to be able to trust that what they set actually took effect.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final TileState tiles = context.watch<TileState>();
    final bool isDark = tiles.isDarkMode;

    // Null in test/offline mode (no auth backend); non-null in the real app.
    AuthController? auth;
    try {
      auth = context.watch<AuthController>();
    } on ProviderNotFoundException {
      auth = null;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: <Widget>[
        const SectionIntro(
          title: 'Settings',
          subtitle: 'Tune how Echo speaks and looks',
        ),
        const SizedBox(height: 20),
        if (auth != null && auth.isLoggedIn) ...<Widget>[
          _Group(
            title: 'Account',
            children: <Widget>[
              _InfoRow(
                icon: Icons.person_outline_rounded,
                label: 'Signed in as',
                value: auth.session?.email ?? '',
              ),
              const _Divider(),
              _NavRow(
                icon: Icons.logout_rounded,
                label: 'Log out',
                subtitle: 'Sign out of your account on this device',
                onTap: () => auth!.logout(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Every account is both things: it has its own board, and it may
          // also control someone else's. So both doors are always shown.
          _Group(
            title: 'Care circle',
            children: <Widget>[
              _NavRow(
                icon: Icons.qr_code_2_rounded,
                label: 'Controller access',
                subtitle: 'Show a code so a guardian can manage this board',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PatientQrPage(),
                  ),
                ),
              ),
              const _Divider(),
              _NavRow(
                icon: Icons.groups_rounded,
                label: 'Patients',
                subtitle: 'Connect to a patient and manage their board',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PatientsPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
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
          title: 'Board layout',
          children: <Widget>[
            _StepperRow(
              icon: Icons.view_column_rounded,
              label: 'Columns',
              subtitle: 'Tiles across the page',
              value: tiles.gridColumns,
              onChanged: (int v) =>
                  context.read<TileState>().setGrid(columns: v),
            ),
            const _Divider(),
            _StepperRow(
              icon: Icons.table_rows_rounded,
              label: 'Rows',
              subtitle: 'Tiles down the page',
              value: tiles.gridRows,
              onChanged: (int v) => context.read<TileState>().setGrid(rows: v),
            ),
            const _Divider(),
            _InfoRow(
              icon: Icons.grid_view_rounded,
              label: 'Tiles per page',
              value: '${tiles.tilesPerPage}',
            ),
            const _Divider(),
            _InfoRow(
              icon: Icons.auto_stories_rounded,
              label: 'Pages',
              value: '${tiles.pageCount}',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Fewer tiles per page means larger, easier targets. Extra tiles '
            'flow onto more pages you can swipe between.',
            style: TextStyle(fontSize: 12, height: 1.45, color: c.muted),
          ),
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

/// A numeric setting adjusted by stepping rather than typing. Both buttons
/// keep their position and simply dim at the bounds, so the control never
/// shifts under a finger that is tapping it repeatedly.
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          _StepButton(
            icon: Icons.remove_rounded,
            enabled: value > kMinGridAxis,
            semanticLabel: 'Fewer $label',
            onTap: () => onChanged(value - 1),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            enabled: value < kMaxGridAxis,
            semanticLabel: 'More $label',
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: enabled
                ? c.surfaceHigh
                : c.surfaceHigh.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: Icon(
            icon,
            size: 19,
            color: enabled ? c.accent : c.muted.withValues(alpha: 0.5),
          ),
        ),
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
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 14, color: c.muted),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/comm_tile.dart';
import '../models/pairing.dart';
import '../state/auth_controller.dart';
import '../state/controller_state.dart';
import '../state/tile_state.dart' show kMaxGridAxis, kMinGridAxis;
import '../theme/app_theme.dart';
import '../theme/tile_themes.dart';
import '../widgets/settings_rows.dart';
import '../widgets/sos_alert_banner.dart';
import '../widgets/tile_editor_sheet.dart';
import '../widgets/tile_glyph.dart';
import 'stats_view.dart';

enum _ConsoleTab { board, stats, setup }

/// The controller's entire app.
///
/// A controller account has no communication board of its own — it exists to
/// set up and watch over one patient. So this replaces the patient shell
/// outright rather than adding a section to it: everything on screen is about
/// the patient, which is what keeps the patient's own device free of setup
/// work they should never have to do.
class ControllerConsole extends StatefulWidget {
  const ControllerConsole({super.key});

  @override
  State<ControllerConsole> createState() => _ControllerConsoleState();
}

class _ControllerConsoleState extends State<ControllerConsole> {
  _ConsoleTab _tab = _ConsoleTab.board;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final ControllerState controller = context.watch<ControllerState>();
    final PatientLink? patient = controller.patient;

    if (patient == null) {
      // Mid-disconnect: the shell above will swap us out on the next frame.
      return Scaffold(
        backgroundColor: c.background,
        body: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: <Widget>[
          const SosAlertBanner(),
          _ConsoleHeader(patient: patient),
          Expanded(
            child: controller.loading
                ? Center(child: CircularProgressIndicator(color: c.accent))
                : switch (_tab) {
                    _ConsoleTab.board => const _BoardTab(),
                    _ConsoleTab.stats => const _StatsTab(),
                    _ConsoleTab.setup => const _SetupTab(),
                  },
          ),
          _ConsoleNav(
            active: _tab,
            onChanged: (_ConsoleTab tab) => setState(() => _tab = tab),
          ),
        ],
      ),
    );
  }
}

class _ConsoleHeader extends StatelessWidget {
  const _ConsoleHeader({required this.patient});

  final PatientLink patient;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: kBrandGradient,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.shield_moon_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Controller console',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: c.muted,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    patient.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsoleNav extends StatelessWidget {
  const _ConsoleNav({required this.active, required this.onChanged});

  final _ConsoleTab active;
  final ValueChanged<_ConsoleTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    Widget item(_ConsoleTab tab, IconData icon, String label) {
      final bool on = tab == active;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(tab),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 23, color: on ? c.accent : c.muted),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: on ? c.accent : c.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            item(_ConsoleTab.board, Icons.dashboard_customize_rounded, 'Board'),
            item(_ConsoleTab.stats, Icons.insights_rounded, 'Stats'),
            item(_ConsoleTab.setup, Icons.tune_rounded, 'Setup'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Board
// ---------------------------------------------------------------------------

class _BoardTab extends StatelessWidget {
  const _BoardTab();

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final ControllerState controller = context.watch<ControllerState>();
    final List<CommTile> tiles = controller.remoteTiles;

    Future<void> addTile() async {
      final TileDraft? draft = await showTileEditor(context);
      if (draft == null || !context.mounted) return;
      await context.read<ControllerState>().addRemoteTile(
        label: draft.label,
        ttsPhrase: draft.ttsPhrase,
        icon: draft.icon,
        colorTheme: draft.colorTheme,
        imageUrl: draft.imageUrl,
      );
    }

    return Stack(
      children: <Widget>[
        if (tiles.isEmpty)
          _EmptyBoard(onAdd: addTile)
        else
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 92),
            itemCount: tiles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) =>
                _RemoteTileRow(tile: tiles[index]),
          ),
        if (controller.error != null)
          Positioned(
            left: 20,
            right: 20,
            top: 0,
            child: Text(
              controller.error!,
              style: TextStyle(fontSize: 12.5, color: c.danger),
            ),
          ),
        if (tiles.isNotEmpty)
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton.extended(
              onPressed: addTile,
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add tile',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

class _RemoteTileRow extends StatelessWidget {
  const _RemoteTileRow({required this.tile});

  final CommTile tile;

  Future<void> _edit(BuildContext context) async {
    final TileDraft? draft = await showTileEditor(context, existing: tile);
    if (draft == null || !context.mounted) return;
    await context.read<ControllerState>().updateRemoteTile(
      tile.id,
      label: draft.label,
      ttsPhrase: draft.ttsPhrase,
      icon: draft.icon,
      colorTheme: draft.colorTheme,
      imageUrl: draft.imageUrl,
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final EchoColors c = EchoColors.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: c.surface,
        title: const Text('Remove tile?'),
        content: Text('“${tile.label}” will be removed from their board.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: c.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Remove', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ControllerState>().removeRemoteTile(tile.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final Color accent = tileAccentFor(tile.colorTheme);

    return GestureDetector(
      onTap: () => _edit(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              padding: EdgeInsets.all(tile.imageUrl != null ? 6 : 0),
              decoration: BoxDecoration(
                color: tile.imageUrl != null
                    ? Colors.white
                    : accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: TileGlyph(
                imageUrl: tile.imageUrl,
                icon: tile.icon,
                iconSize: 24,
                color: accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    tile.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tile.ttsPhrase,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _confirmDelete(context),
              icon: Icon(Icons.delete_outline_rounded, color: c.muted),
              tooltip: 'Remove ${tile.label}',
            ),
            Icon(Icons.chevron_right_rounded, color: c.muted),
          ],
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.grid_view_rounded, size: 52, color: c.muted),
            const SizedBox(height: 14),
            Text(
              'Their board is empty.',
              style: TextStyle(fontSize: 16, color: c.muted),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  'Add tile',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

class _StatsTab extends StatelessWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context) {
    final ControllerState controller = context.watch<ControllerState>();

    return StatsBody(
      utterances: controller.remoteLog,
      tiles: controller.remoteTiles,
      onRefresh: context.read<ControllerState>().refreshStats,
    );
  }
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

class _SetupTab extends StatelessWidget {
  const _SetupTab();

  Future<void> _confirmDisconnect(BuildContext context) async {
    final EchoColors c = EchoColors.of(context);
    final ControllerState controller = context.read<ControllerState>();
    final String name = controller.patient?.displayName ?? 'this patient';

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: c.surface,
        title: const Text('Disconnect patient?'),
        content: Text(
          'You will stop managing $name and will no longer receive their '
          'emergency alerts. Their board is not deleted.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: c.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Disconnect', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (ok == true) await controller.disconnectPatient();
  }

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final ControllerState controller = context.watch<ControllerState>();

    AuthController? auth;
    try {
      auth = context.watch<AuthController>();
    } on ProviderNotFoundException {
      auth = null;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: <Widget>[
        SettingsGroup(
          title: 'Their board layout',
          children: <Widget>[
            SettingsStepperRow(
              icon: Icons.view_column_rounded,
              label: 'Columns',
              subtitle: 'Tiles across their page',
              value: controller.remoteColumns,
              min: kMinGridAxis,
              max: kMaxGridAxis,
              onChanged: (int v) =>
                  context.read<ControllerState>().setRemoteGrid(columns: v),
            ),
            const SettingsDivider(),
            SettingsStepperRow(
              icon: Icons.table_rows_rounded,
              label: 'Rows',
              subtitle: 'Tiles down their page',
              value: controller.remoteRows,
              min: kMinGridAxis,
              max: kMaxGridAxis,
              onChanged: (int v) =>
                  context.read<ControllerState>().setRemoteGrid(rows: v),
            ),
            const SettingsDivider(),
            SettingsInfoRow(
              icon: Icons.grid_view_rounded,
              label: 'Tiles per page',
              value: '${controller.remoteTilesPerPage}',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Fewer tiles per page means larger, easier targets on their '
            'device. Extra tiles flow onto more pages.',
            style: TextStyle(fontSize: 12, height: 1.45, color: c.muted),
          ),
        ),
        const SizedBox(height: 14),
        SettingsGroup(
          title: 'Their appearance',
          children: <Widget>[
            SettingsSwitchRow(
              icon: controller.remoteDarkMode
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              label: 'Dark mode',
              subtitle: 'Applies to the patient device',
              value: controller.remoteDarkMode,
              onChanged: (bool v) =>
                  context.read<ControllerState>().setRemoteDarkMode(v),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsGroup(
          title: 'Connection',
          children: <Widget>[
            SettingsInfoRow(
              icon: Icons.link_rounded,
              label: 'Managing',
              value: controller.patient?.displayName ?? '—',
            ),
            const SettingsDivider(),
            SettingsNavRow(
              icon: Icons.link_off_rounded,
              label: 'Disconnect patient',
              subtitle: 'Hand this patient back and return to your own device',
              tint: c.danger,
              onTap: () => _confirmDisconnect(context),
            ),
          ],
        ),
        if (auth != null && auth.isLoggedIn) ...<Widget>[
          const SizedBox(height: 14),
          SettingsGroup(
            title: 'Account',
            children: <Widget>[
              SettingsInfoRow(
                icon: Icons.person_outline_rounded,
                label: 'Signed in as',
                value: auth.session?.email ?? '',
              ),
              const SettingsDivider(),
              SettingsNavRow(
                icon: Icons.logout_rounded,
                label: 'Log out',
                subtitle: 'Sign out on this device',
                onTap: () => auth!.logout(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

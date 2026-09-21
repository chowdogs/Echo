import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pairing.dart';
import '../state/auth_controller.dart';
import '../state/controller_state.dart';
import '../state/tile_state.dart';
import '../theme/app_theme.dart';
import '../widgets/section_intro.dart';
import '../widgets/settings_rows.dart';
import 'board_editor_page.dart';
import 'connect_patient_page.dart';
import 'patient_qr_page.dart';
import 'stats_view.dart';

/// The patient's settings.
///
/// The patient keeps full control of their own board, always. A guardian is an
/// extra pair of hands — someone who can do the setup work *instead of* them,
/// from their own device — not a replacement for it. If the guardian is away
/// or offline, every control here still works.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<ControllerState>().refreshGuardians();
      } on ProviderNotFoundException {
        // Offline/test mode — no pairing backend.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final TileState tiles = context.watch<TileState>();

    AuthController? auth;
    ControllerState? care;
    try {
      auth = context.watch<AuthController>();
      care = context.watch<ControllerState>();
    } on ProviderNotFoundException {
      auth = null;
      care = null;
    }

    final List<PatientLink> guardians = care?.guardians ?? <PatientLink>[];
    final bool managed = guardians.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: <Widget>[
        const SectionIntro(
          title: 'Settings',
          subtitle: 'Who helps you, and how Echo looks',
        ),
        const SizedBox(height: 20),

        if (auth != null && auth.isLoggedIn) ...<Widget>[
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
                subtitle: 'Sign out of your account on this device',
                onTap: () => auth!.logout(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          SettingsGroup(
            title: 'My guardians',
            children: <Widget>[
              for (final PatientLink guardian in guardians) ...<Widget>[
                _GuardianRow(guardian: guardian),
                const SettingsDivider(),
              ],
              if (care != null && care.canAddGuardian)
                SettingsNavRow(
                  icon: Icons.qr_code_2_rounded,
                  label: 'Add a guardian',
                  subtitle:
                      'Show a code so they can manage this device '
                      '(${guardians.length} of $kMaxGuardiansPerPatient)',
                  // Refresh on the way back, so a guardian added on the QR
                  // screen is already listed the moment it closes.
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PatientQrPage(),
                      ),
                    );
                    if (!context.mounted) return;
                    await context.read<ControllerState>().refreshGuardians();
                  },
                )
              else
                SettingsInfoRow(
                  icon: Icons.group_rounded,
                  label: 'Guardians',
                  value: '$kMaxGuardiansPerPatient of '
                      '$kMaxGuardiansPerPatient (full)',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              managed
                  ? 'Your guardian sets up your board, layout and appearance '
                        'from their own device, and is alerted when you press '
                        'SOS.'
                  : 'A guardian can set up this board for you from their own '
                        'device, and will be alerted when you press SOS.',
              style: TextStyle(fontSize: 12, height: 1.45, color: c.muted),
            ),
          ),
          const SizedBox(height: 14),

          SettingsGroup(
            title: 'Caring for someone else',
            children: <Widget>[
              SettingsNavRow(
                icon: Icons.switch_account_rounded,
                label: 'Become a controller',
                subtitle: 'Connect to a patient and manage their device',
                onTap: () {
                  context.read<ControllerState>().clearError();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ConnectPatientPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],

        SettingsGroup(
          title: 'Appearance',
          children: <Widget>[
            SettingsSwitchRow(
              icon: tiles.isDarkMode
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              label: 'Dark mode',
              subtitle: tiles.isDarkMode
                  ? 'Deep slate theme'
                  : 'Light theme (default)',
              value: tiles.isDarkMode,
              onChanged: (bool v) => context.read<TileState>().setDarkMode(v),
            ),
          ],
        ),

        // The patient never loses control of their own board. A guardian is an
        // extra pair of hands, not a replacement: if the guardian's device is
        // offline or absent, everything here still works from this device.
        ...<Widget>[
          const SizedBox(height: 14),
          SettingsGroup(
            title: 'Board',
            children: <Widget>[
              SettingsStepperRow(
                icon: Icons.view_column_rounded,
                label: 'Columns',
                subtitle: 'Tiles across the page',
                value: tiles.gridColumns,
                min: kMinGridAxis,
                max: kMaxGridAxis,
                onChanged: (int v) =>
                    context.read<TileState>().setGrid(columns: v),
              ),
              const SettingsDivider(),
              SettingsStepperRow(
                icon: Icons.table_rows_rounded,
                label: 'Rows',
                subtitle: 'Tiles down the page',
                value: tiles.gridRows,
                min: kMinGridAxis,
                max: kMaxGridAxis,
                onChanged: (int v) =>
                    context.read<TileState>().setGrid(rows: v),
              ),
              const SettingsDivider(),
              SettingsNavRow(
                icon: Icons.dashboard_customize_rounded,
                label: 'Edit communication board',
                subtitle: 'Add, rename, or remove tiles',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BoardEditorPage(),
                  ),
                ),
              ),
              const SettingsDivider(),
              SettingsNavRow(
                icon: Icons.insights_rounded,
                label: 'Stats',
                subtitle: 'Daily communications & recent activity',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const StatsPage()),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 14),
        SettingsGroup(
          title: 'About',
          children: const <Widget>[
            SettingsInfoRow(
              icon: Icons.info_outline_rounded,
              label: 'Version',
              value: '0.1.0',
            ),
            SettingsDivider(),
            SettingsInfoRow(
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

/// One guardian, with the patient's ability to revoke them.
class _GuardianRow extends StatelessWidget {
  const _GuardianRow({required this.guardian});

  final PatientLink guardian;

  Future<void> _confirmRemove(BuildContext context) async {
    final EchoColors c = EchoColors.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: c.surface,
        title: const Text('Remove guardian?'),
        content: Text(
          '${guardian.displayName} will no longer be able to manage this '
          'device or receive your emergency alerts.',
        ),
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
      await context.read<ControllerState>().removeGuardian(guardian.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: <Widget>[
          const SettingsRowIcon(Icons.shield_moon_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  guardian.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Can manage this board',
                  style: TextStyle(fontSize: 12.5, color: c.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _confirmRemove(context),
            icon: Icon(Icons.person_remove_rounded, color: c.muted, size: 21),
            tooltip: 'Remove ${guardian.displayName}',
          ),
        ],
      ),
    );
  }
}

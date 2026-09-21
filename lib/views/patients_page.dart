import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/comm_tile.dart';
import '../models/pairing.dart';
import '../state/controller_state.dart';
import '../theme/app_theme.dart';
import '../theme/tile_themes.dart';
import '../widgets/sub_page_header.dart';
import '../widgets/tile_editor_sheet.dart';
import '../widgets/tile_glyph.dart';
import 'connect_patient_page.dart';

/// The guardian's home for the accounts they manage.
class PatientsPage extends StatefulWidget {
  const PatientsPage({super.key});

  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ControllerState>().refreshPatients(),
    );
  }

  Future<void> _connect() async {
    context.read<ControllerState>().clearError();
    await Navigator.of(context).push(
      MaterialPageRoute<PatientLink>(
        builder: (_) => const ConnectPatientPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final ControllerState controller = context.watch<ControllerState>();
    final List<PatientLink> patients = controller.patients;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: <Widget>[
          const SubPageHeader(
            title: 'Patients',
            subtitle: 'Boards you manage as a controller',
          ),
          Expanded(
            child: patients.isEmpty
                ? _EmptyPatients(onConnect: _connect)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    itemCount: patients.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) =>
                        _PatientRow(patient: patients[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: patients.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _connect,
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                'Connect',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient});

  final PatientLink patient;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        context.read<ControllerState>().openPatientBoard(patient);
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PatientBoardPage()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.account_circle_rounded,
                color: c.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    patient.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to manage their board',
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

class _EmptyPatients extends StatelessWidget {
  const _EmptyPatients({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.groups_rounded, size: 56, color: c.muted),
            const SizedBox(height: 16),
            const Text(
              'No patients yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to a patient to set up their board from here and '
              'receive their emergency alerts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: c.muted),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onConnect,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  gradient: kBrandGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Connect a patient',
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

/// A patient's board, edited remotely by their guardian.
///
/// Deliberately the same shape as the local board editor, so a caregiver who
/// has set up their own device already knows this screen.
class PatientBoardPage extends StatelessWidget {
  const PatientBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final ControllerState controller = context.watch<ControllerState>();
    final List<CommTile> tiles = controller.remoteTiles;
    final PatientLink? patient = controller.openPatient;

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

    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) context.read<ControllerState>().closePatientBoard();
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: Column(
          children: <Widget>[
            SubPageHeader(
              title: patient?.displayName ?? 'Patient board',
              subtitle: controller.boardBusy
                  ? 'Loading…'
                  : '${tiles.length} ${tiles.length == 1 ? 'tile' : 'tiles'}',
            ),
            if (controller.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.error_outline_rounded,
                      size: 17,
                      color: c.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.error!,
                        style: TextStyle(fontSize: 12.5, color: c.danger),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: controller.boardBusy
                  ? Center(child: CircularProgressIndicator(color: c.accent))
                  : tiles.isEmpty
                  ? _EmptyRemoteBoard(onAdd: addTile)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      itemCount: tiles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) =>
                          _RemoteTileRow(tile: tiles[index]),
                    ),
            ),
          ],
        ),
        floatingActionButton: controller.boardBusy || tiles.isEmpty
            ? null
            : FloatingActionButton.extended(
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

class _EmptyRemoteBoard extends StatelessWidget {
  const _EmptyRemoteBoard({required this.onAdd});

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

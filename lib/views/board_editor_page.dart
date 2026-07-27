import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/comm_tile.dart';
import '../state/tile_state.dart';
import '../theme/app_theme.dart';
import '../theme/tile_themes.dart';
import '../widgets/sub_page_header.dart';
import '../widgets/tile_editor_sheet.dart';

/// Full-screen board manager, pushed from Settings.
///
/// Everything a caregiver needs to shape the board lives here: add a tile,
/// rename it, change its icon or colour, or remove it. Kept as its own route
/// rather than a tab so it feels like a focused task you enter and leave.
class BoardEditorPage extends StatelessWidget {
  const BoardEditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final List<CommTile> tiles = context.watch<TileState>().tiles;

    Future<void> addTile() async {
      final TileDraft? draft = await showTileEditor(context);
      if (draft == null || !context.mounted) return;
      context.read<TileState>().addTile(
        label: draft.label,
        ttsPhrase: draft.ttsPhrase,
        icon: draft.icon,
        colorTheme: draft.colorTheme,
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: <Widget>[
          SubPageHeader(
            title: 'Edit board',
            subtitle: '${tiles.length} ${tiles.length == 1 ? 'tile' : 'tiles'}',
          ),
          Expanded(
            child: tiles.isEmpty
                ? _EmptyState(onAdd: addTile)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    itemCount: tiles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      return _TileRow(tile: tiles[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: tiles.isEmpty
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
    );
  }
}

class _TileRow extends StatelessWidget {
  const _TileRow({required this.tile});

  final CommTile tile;

  Future<void> _edit(BuildContext context) async {
    final TileDraft? draft = await showTileEditor(context, existing: tile);
    if (draft == null || !context.mounted) return;
    context.read<TileState>().updateTile(
      tile.id,
      label: draft.label,
      ttsPhrase: draft.ttsPhrase,
      icon: draft.icon,
      colorTheme: draft.colorTheme,
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final EchoColors c = EchoColors.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: c.surface,
          title: const Text('Remove tile?'),
          content: Text('“${tile.label}” will be removed from the board.'),
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
        );
      },
    );
    if (ok == true && context.mounted) {
      context.read<TileState>().removeTile(tile.id);
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
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(tile.icon, color: accent, size: 24),
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
            const SizedBox(width: 8),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

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
            Icon(Icons.grid_view_rounded, size: 56, color: c.muted),
            const SizedBox(height: 16),
            const Text(
              'The board is empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your first tile to start building the board.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: c.muted),
            ),
            const SizedBox(height: 22),
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

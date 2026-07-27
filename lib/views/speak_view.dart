import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/comm_tile.dart';
import '../state/tile_state.dart';
import '../theme/app_theme.dart';
import '../widgets/section_intro.dart';
import '../widgets/tile_button.dart';

/// The primary communication surface: a 3x3 grid of tiles that fills the
/// content area edge to edge.
class SpeakView extends StatelessWidget {
  const SpeakView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: SectionIntro(
            title: 'Speak',
            subtitle: 'Tap a tile to say it out loud',
          ),
        ),
        Expanded(child: _TileGrid()),
      ],
    );
  }
}

/// The 3x3 board.
///
/// Sized to fit the available space rather than scrolled. AAC users navigate
/// by remembered tile position, so a board that scrolls — where a tile's
/// location depends on scroll offset — breaks the core interaction. As long as
/// the board fits, every tile stays on screen and scales to fill.
///
/// Once a caregiver adds enough tiles that fitting them all would make the
/// targets too small to tap reliably, the board falls back to a scrolling grid
/// at a fixed comfortable size — shrinking tiles indefinitely would be worse
/// for the motor-precision users this is built for.
class _TileGrid extends StatelessWidget {
  const _TileGrid();

  static const double _padding = 20;
  static const double _spacing = 14;
  static const int _columns = 3;

  /// Below this, tiles are too small to be dependable targets, so we scroll
  /// instead of shrinking further.
  static const double _minComfortableCell = 96;

  @override
  Widget build(BuildContext context) {
    final List<CommTile> tiles = context.watch<TileState>().tiles;
    final void Function(CommTile) onActivate = context.read<TileState>().speak;

    if (tiles.isEmpty) {
      return const _EmptyBoard();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double colGaps = _spacing * (_columns - 1);
        final int rows = (tiles.length / _columns).ceil();
        final double availableWidth = constraints.maxWidth - (_padding * 2);
        final double availableHeight = constraints.maxHeight - (_padding * 2);

        final double cellByWidth = (availableWidth - colGaps) / _columns;
        final double cellByHeight =
            (availableHeight - (_spacing * (rows - 1))) / rows;

        // Square tiles, so the tighter dimension wins when fitting to screen.
        final double fittedCell = math.min(cellByWidth, cellByHeight);

        final List<Widget> children = <Widget>[
          for (final CommTile tile in tiles)
            TileButton(tile: tile, onActivate: onActivate),
        ];

        // Comfortable fit: lay the whole board out centred, no scrolling.
        if (fittedCell >= _minComfortableCell) {
          final double boardWidth = (fittedCell * _columns) + colGaps;
          final double boardHeight =
              (fittedCell * rows) + (_spacing * (rows - 1));

          return Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                _padding,
                0,
                _padding,
                _padding,
              ),
              child: SizedBox(
                width: boardWidth.clamp(0, availableWidth),
                height: boardHeight.clamp(0, availableHeight),
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  crossAxisCount: _columns,
                  crossAxisSpacing: _spacing,
                  mainAxisSpacing: _spacing,
                  children: children,
                ),
              ),
            ),
          );
        }

        // Too many tiles to fit: scroll at a width-based comfortable size.
        return GridView.count(
          padding: const EdgeInsets.fromLTRB(_padding, 0, _padding, _padding),
          crossAxisCount: _columns,
          crossAxisSpacing: _spacing,
          mainAxisSpacing: _spacing,
          children: children,
        );
      },
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

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
              'No tiles yet.\nAdd some in Settings → Edit board.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.5, color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

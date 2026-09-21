import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/comm_tile.dart';
import '../state/tile_state.dart';
import '../theme/app_theme.dart';
import '../widgets/tile_button.dart';

/// The primary communication surface.
///
/// The board is *paged*, not scrolled. AAC users navigate by remembered tile
/// position, so every tile keeps a fixed slot on its page and the page turns
/// as a whole — a scrolling board, where a tile's location depends on scroll
/// offset, breaks that. The caregiver chooses how many tiles fill a page
/// (Settings -> Board layout), and whatever they choose, the tiles expand to
/// use the entire area: bigger targets are easier to hit reliably.
class SpeakView extends StatefulWidget {
  const SpeakView({super.key});

  @override
  State<SpeakView> createState() => _SpeakViewState();
}

class _SpeakViewState extends State<SpeakView> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TileState state = context.watch<TileState>();
    final int pageCount = state.pageCount;

    // Deleting tiles or shrinking the layout can strand us past the last
    // page; step back to the final one rather than showing a blank board.
    if (_page > pageCount - 1) {
      _page = pageCount - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(_page);
        }
      });
    }

    return Column(
      children: <Widget>[
        _Header(page: _page, pageCount: pageCount),
        Expanded(
          child: state.tiles.isEmpty
              ? const _EmptyBoard()
              : PageView.builder(
                  controller: _controller,
                  itemCount: pageCount,
                  onPageChanged: (int page) => setState(() => _page = page),
                  itemBuilder: (BuildContext context, int index) {
                    return _BoardPage(
                      tiles: state.tilesForPage(index),
                      columns: state.gridColumns,
                      rows: state.gridRows,
                    );
                  },
                ),
        ),
        if (pageCount > 1) _PageDots(count: pageCount, active: _page),
      ],
    );
  }
}

/// A deliberately slim header — every pixel it gives up goes to the tiles.
class _Header extends StatelessWidget {
  const _Header({required this.page, required this.pageCount});

  final int page;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: <Widget>[
          const Text(
            'Speak',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(width: 12),
          // Expanded rather than a Spacer: on a narrow phone the hint text is
          // wider than the row can give it, and it must ellipsize instead of
          // overflowing.
          Expanded(
            child: Text(
              pageCount > 1
                  ? 'Page ${page + 1} of $pageCount'
                  : 'Tap a tile to say it out loud',
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: c.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// One page of the board: exactly `columns x rows` slots, sized so the grid
/// fills the page edge to edge with no leftover space.
class _BoardPage extends StatelessWidget {
  const _BoardPage({
    required this.tiles,
    required this.columns,
    required this.rows,
  });

  final List<CommTile> tiles;
  final int columns;
  final int rows;

  static const double _padding = 14;
  static const double _spacing = 12;

  @override
  Widget build(BuildContext context) {
    final void Function(CommTile) onActivate = context.read<TileState>().speak;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double availableWidth = constraints.maxWidth - (_padding * 2);
        final double availableHeight = constraints.maxHeight - (_padding * 2);

        final double cellWidth =
            (availableWidth - (_spacing * (columns - 1))) / columns;
        final double cellHeight =
            (availableHeight - (_spacing * (rows - 1))) / rows;

        // The cell ratio is what makes the grid fill the page exactly. Guard
        // the degenerate case so a cramped first frame can't divide by zero.
        final double aspect = (cellWidth <= 0 || cellHeight <= 0)
            ? 1.0
            : cellWidth / cellHeight;

        return GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(_padding),
          crossAxisCount: columns,
          crossAxisSpacing: _spacing,
          mainAxisSpacing: _spacing,
          childAspectRatio: aspect,
          children: <Widget>[
            for (final CommTile tile in tiles)
              TileButton(tile: tile, onActivate: onActivate),
          ],
        );
      },
    );
  }
}

/// Page position indicator. The active page widens into a pill so the current
/// position reads at a glance without counting dots.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(count, (int index) {
          final bool isActive = index == active;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 20 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: isActive ? c.accent : c.border,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
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
              'No tiles yet.\nAdd some in Settings -> Edit board.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.5, color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

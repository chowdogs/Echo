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
        if (pageCount > 1)
          _PageNav(
            count: pageCount,
            active: _page,
            onGo: (int page) => _goToPage(page, pageCount),
          ),
      ],
    );
  }

  /// Moves the board a page at a time. Swiping still works, but every page
  /// change is reachable by tapping alone — a swipe is a gesture plenty of
  /// AAC users cannot make reliably, and the board must never depend on one.
  void _goToPage(int page, int pageCount) {
    if (page < 0 || page >= pageCount || !_controller.hasClients) return;
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
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

/// Page navigation: a large Previous / Next button either side of the page
/// indicator.
///
/// The buttons are the primary control, not a convenience — swiping is a
/// gesture many AAC users cannot perform, so every page must be reachable by
/// tapping. They are sized as generously as the strip allows, and dim rather
/// than disappear at the ends so the control never shifts position.
class _PageNav extends StatelessWidget {
  const _PageNav({
    required this.count,
    required this.active,
    required this.onGo,
  });

  final int count;
  final int active;
  final ValueChanged<int> onGo;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      child: Row(
        children: <Widget>[
          _NavButton(
            icon: Icons.chevron_left_rounded,
            label: 'Previous page',
            enabled: active > 0,
            onTap: () => onGo(active - 1),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(count, (int index) {
                final bool isActive = index == active;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? c.accent : c.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            label: 'Next page',
            enabled: active < count - 1,
            onTap: () => onGo(active + 1),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          width: 62,
          height: 48,
          decoration: BoxDecoration(
            color: enabled ? c.surface : c.surface.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled ? c.border : c.border.withValues(alpha: 0.5),
            ),
          ),
          child: Icon(
            icon,
            size: 30,
            color: enabled ? c.accent : c.muted.withValues(alpha: 0.45),
          ),
        ),
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

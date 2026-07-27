import 'package:flutter/material.dart';

import '../models/comm_tile.dart';
import '../theme/app_theme.dart';
import '../theme/tile_themes.dart';

/// A single communication tile.
///
/// The whole card is the tap target rather than an inner icon — motor
/// precision is the constraint that matters most for this control, so the hit
/// area is made as large as the grid cell allows.
///
/// Visually it is a uniform dark card, not a saturated colour block: the
/// category colour appears only as the icon tint and a faint chip behind it.
/// That is what keeps the board reading as an adult tool.
class TileButton extends StatefulWidget {
  const TileButton({super.key, required this.tile, required this.onActivate});

  final CommTile tile;
  final ValueChanged<CommTile> onActivate;

  @override
  State<TileButton> createState() => _TileButtonState();
}

class _TileButtonState extends State<TileButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = tileAccentFor(widget.tile.colorTheme);
    final EchoColors c = EchoColors.of(context);

    return Semantics(
      button: true,
      // The spoken sentence, not the short face label — a screen-reader user
      // should hear what the tile will actually say.
      label: widget.tile.ttsPhrase,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () => widget.onActivate(widget.tile),
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                // The border lifts to the category colour on press — a quiet
                // confirmation of which tile fired.
                color: _isPressed ? accent.withValues(alpha: 0.9) : c.border,
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _isPressed
                      ? accent.withValues(alpha: 0.22)
                      : Colors.black.withValues(alpha: 0.25),
                  blurRadius: _isPressed ? 18 : 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double cell = constraints.biggest.shortestSide;
                final double chip = (cell * 0.42).clamp(40.0, 78.0);

                return Padding(
                  padding: EdgeInsets.all((cell * 0.10).clamp(8.0, 18.0)),
                  // The outer FittedBox is a guarantee, not the primary sizing:
                  // the cell-derived sizes below look right on normal tiles,
                  // and on unusually short cells this quietly scales the whole
                  // stack down instead of overflowing.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: chip,
                          height: chip,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(chip * 0.3),
                          ),
                          child: Icon(
                            widget.tile.icon,
                            size: chip * 0.52,
                            color: accent,
                          ),
                        ),
                        SizedBox(height: (cell * 0.08).clamp(6.0, 14.0)),
                        Text(
                          widget.tile.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: (cell * 0.15).clamp(13.0, 19.0),
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: c.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

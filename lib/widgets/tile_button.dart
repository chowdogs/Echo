import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/comm_tile.dart';
import '../theme/app_theme.dart';
import '../theme/tile_themes.dart';
import 'tile_glyph.dart';

/// A single communication tile.
///
/// This is the product. Everything else in the app exists so that this button
/// is correct, so it is the one element allowed to be loud.
///
/// The whole card is the tap target rather than an inner icon — motor
/// precision is the constraint that matters most here, so the hit area is as
/// large as the grid cell allows.
///
/// The category colour runs through the whole tile (a tinted surface, a
/// coloured edge, a solid glyph) instead of appearing only as a small icon
/// tint. Colour-coding is a real wayfinding aid for AAC users — "amber means
/// food" — but only if it is visible from across a room. The tint stays low
/// enough that the board still reads as an adult tool rather than a toy.
class TileButton extends StatefulWidget {
  const TileButton({
    super.key,
    required this.tile,
    required this.onActivate,
    this.scanHighlighted = false,
  });

  final CommTile tile;
  final ValueChanged<CommTile> onActivate;

  /// True while the scanning highlight is resting on this tile. It has to be
  /// unmistakable from across a room and distinguishable without relying on
  /// colour, so it reads as a thick ring plus a lift rather than a tint.
  final bool scanHighlighted;

  @override
  State<TileButton> createState() => _TileButtonState();
}

class _TileButtonState extends State<TileButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  void _activate() {
    // A confirmation the user can feel, for someone who may not hear the
    // phrase over background noise or see the colour change clearly.
    HapticFeedback.mediumImpact();
    widget.onActivate(widget.tile);
  }

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final Color accent = tileAccentOf(context, widget.tile.colorTheme);
    final bool hasImage = widget.tile.imageUrl != null;

    final bool lit = _isPressed || widget.scanHighlighted;

    return Semantics(
      button: true,
      selected: widget.scanHighlighted,
      // The spoken sentence, not the short face label — a screen-reader user
      // should hear what the tile will actually say.
      label: widget.tile.ttsPhrase,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _activate,
        child: AnimatedScale(
          scale: _isPressed
              ? 0.955
              : widget.scanHighlighted
              ? 1.03
              : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            decoration: BoxDecoration(
              color: lit
                  ? c.tintedSurface(accent, strength: 2.2)
                  : c.tintedSurface(accent),
              borderRadius: BorderRadius.circular(EchoRadius.xl),
              border: Border.all(
                color: accent.withValues(alpha: lit ? 0.95 : 0.34),
                width: widget.scanHighlighted ? 4 : (_isPressed ? 2.5 : 1.5),
              ),
              boxShadow: lit
                  ? <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.30),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : c.elevation(),
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double cell = constraints.biggest.shortestSide;
                final double glyph = (cell * 0.46).clamp(44.0, 104.0);

                return Padding(
                  padding: EdgeInsets.all((cell * 0.09).clamp(8.0, 18.0)),
                  // The FittedBox is a guarantee, not the primary sizing: the
                  // cell-derived sizes look right on normal tiles, and on an
                  // unusually short cell this scales the stack down instead
                  // of overflowing.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: glyph,
                          height: glyph,
                          padding: EdgeInsets.all(hasImage ? glyph * 0.10 : 0),
                          decoration: BoxDecoration(
                            // A pictogram reads truest on white; an icon sits
                            // on a stronger wash of its own category colour.
                            color: hasImage
                                ? Colors.white
                                : accent.withValues(
                                    alpha: c.isDark ? 0.22 : 0.15,
                                  ),
                            borderRadius: BorderRadius.circular(glyph * 0.3),
                          ),
                          child: TileGlyph(
                            imageUrl: widget.tile.imageUrl,
                            icon: widget.tile.icon,
                            iconSize: glyph * 0.56,
                            color: accent,
                          ),
                        ),
                        SizedBox(height: (cell * 0.075).clamp(7.0, 15.0)),
                        Text(
                          widget.tile.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: (cell * 0.165).clamp(14.0, 24.0),
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
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

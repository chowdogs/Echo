import 'package:flutter/material.dart';

import 'app_theme.dart';

/// A category colour, in the two forms it needs to take.
///
/// One hex value cannot serve both modes: a tone deep enough to read as an
/// icon on a white card is nearly invisible on dark slate, and a tone bright
/// enough for dark slate washes out on white. So each category carries both,
/// and [EchoColors.isDark] picks.
@immutable
class TileAccent {
  const TileAccent({required this.light, required this.dark});

  /// For light mode — deep enough to pass contrast as an icon or label.
  final Color light;

  /// For dark mode — lifted so it reads against the slate canvas.
  final Color dark;

  Color resolve(bool isDark) => isDark ? dark : light;
}

/// Per-category accent colours.
///
/// Deliberately not the saturated primaries a children's board would use —
/// these are deepened, slightly desaturated hues that stay adult. They are,
/// however, *present*: the previous palette was so muted that the category
/// colour survived only as a faint icon tint, which defeated the point.
/// Colour-coding only helps if a user can actually scan by it, so each tile
/// now carries its hue in the surface, the border, and the glyph.
///
/// The hues are spaced far enough apart in both lightness and hue to stay
/// distinguishable under the common colour-vision deficiencies.
const Map<String, TileAccent> kTileAccents = <String, TileAccent>{
  'sky': TileAccent(light: Color(0xFF0B74C4), dark: Color(0xFF5CB8F5)),
  'emerald': TileAccent(light: Color(0xFF0E8A62), dark: Color(0xFF45CFA2)),
  'amber': TileAccent(light: Color(0xFFA8690B), dark: Color(0xFFE8B055)),
  'orange': TileAccent(light: Color(0xFFBF5A1E), dark: Color(0xFFF58F57)),
  'rose': TileAccent(light: Color(0xFFC32B52), dark: Color(0xFFFF7A95)),
  'violet': TileAccent(light: Color(0xFF6B4FD8), dark: Color(0xFFA896FF)),
  'indigo': TileAccent(light: Color(0xFF3B55D9), dark: Color(0xFF8095FF)),
  'teal': TileAccent(light: Color(0xFF0D7E80), dark: Color(0xFF43C7C9)),
  'slate': TileAccent(light: Color(0xFF4A5B74), dark: Color(0xFFA3B3CA)),
};

const TileAccent kDefaultTileAccent = TileAccent(
  light: Color(0xFF4A5B74),
  dark: Color(0xFFA3B3CA),
);

/// The accent for [colorTheme], already resolved for the active mode.
Color tileAccentFor(String colorTheme, {bool isDark = false}) =>
    (kTileAccents[colorTheme] ?? kDefaultTileAccent).resolve(isDark);

/// Convenience for widgets that already have a [BuildContext].
Color tileAccentOf(BuildContext context, String colorTheme) =>
    tileAccentFor(colorTheme, isDark: EchoColors.of(context).isDark);

/// Colour keys in a stable order, for the editor's colour picker.
const List<String> kTileColorChoices = <String>[
  'sky',
  'emerald',
  'amber',
  'orange',
  'rose',
  'violet',
  'indigo',
  'teal',
  'slate',
];

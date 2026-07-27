import 'package:flutter/material.dart';

/// Per-category accent colours.
///
/// These are deliberately muted rather than the saturated primaries a
/// children's board would use. In the new design the tile surface is a uniform
/// dark card; the category colour survives only as the icon tint and a faint
/// chip behind it. That keeps the clinical value of colour-coded categories
/// (a user learns "amber = food") without the toy-like look of full colour
/// fills, and the hues stay far enough apart to remain distinguishable under
/// common colour-vision deficiencies.
const Map<String, Color> kTileAccents = <String, Color>{
  'amber': Color(0xFFE0A458),
  'sky': Color(0xFF5AA9E6),
  'rose': Color(0xFFE0728A),
  'violet': Color(0xFF9B8CFF),
  'emerald': Color(0xFF4FBF9F),
  'slate': Color(0xFF9DB0C7),
  'orange': Color(0xFFE8945A),
  'teal': Color(0xFF48C4C0),
  'indigo': Color(0xFF7C8CF5),
};

const Color kDefaultTileAccent = Color(0xFF9DB0C7);

Color tileAccentFor(String colorTheme) =>
    kTileAccents[colorTheme] ?? kDefaultTileAccent;

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

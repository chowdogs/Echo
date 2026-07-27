import 'package:flutter/widgets.dart';

/// A single communication tile.
///
/// Deliberately holds no styling — [colorTheme] is a key that the widget layer
/// resolves against the palette. That keeps tile data serialisable, which
/// matters once boards are user-editable and saved to disk.
class CommTile {
  const CommTile({
    required this.id,
    required this.label,
    required this.ttsPhrase,
    required this.icon,
    required this.colorTheme,
  });

  final String id;

  /// Short text shown on the tile face.
  final String label;

  /// The full sentence spoken aloud. Longer than [label] on purpose: the tile
  /// reads "Hungry" but says "I am hungry."
  final String ttsPhrase;

  /// A clean line/solid glyph from the Material set. Chosen over emoji on
  /// purpose — emoji render as cartoons and skew the whole board childish;
  /// a consistent icon set reads as an adult communication tool.
  final IconData icon;

  final String colorTheme;

  CommTile copyWith({
    String? label,
    String? ttsPhrase,
    IconData? icon,
    String? colorTheme,
  }) {
    return CommTile(
      id: id,
      label: label ?? this.label,
      ttsPhrase: ttsPhrase ?? this.ttsPhrase,
      icon: icon ?? this.icon,
      colorTheme: colorTheme ?? this.colorTheme,
    );
  }
}

/// One recorded utterance. Feeds the caregiver dashboard.
class Utterance {
  const Utterance({
    required this.tileId,
    required this.label,
    required this.spokenAt,
  });

  final String tileId;
  final String label;
  final DateTime spokenAt;
}

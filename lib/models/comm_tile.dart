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
    this.imageUrl,
  });

  final String id;

  /// Short text shown on the tile face.
  final String label;

  /// The full sentence spoken aloud. Longer than [label] on purpose: the tile
  /// reads "Hungry" but says "I am hungry."
  final String ttsPhrase;

  /// A clean line/solid glyph from the Material set. Always present as the
  /// fallback: if [imageUrl] is null, or a pictogram fails to load, the tile
  /// shows this icon instead.
  final IconData icon;

  final String colorTheme;

  /// Optional ARASAAC pictogram image fetched from the internet. When set, the
  /// tile shows this communication symbol instead of [icon].
  final String? imageUrl;

  /// Sentinel used by [copyWith] to tell "leave [imageUrl] unchanged" apart
  /// from "set [imageUrl] to null" — a plain nullable parameter can't express
  /// the difference.
  static const Object keep = Object();

  CommTile copyWith({
    String? label,
    String? ttsPhrase,
    IconData? icon,
    String? colorTheme,
    Object? imageUrl = keep,
  }) {
    return CommTile(
      id: id,
      label: label ?? this.label,
      ttsPhrase: ttsPhrase ?? this.ttsPhrase,
      icon: icon ?? this.icon,
      colorTheme: colorTheme ?? this.colorTheme,
      imageUrl: identical(imageUrl, keep) ? this.imageUrl : imageUrl as String?,
    );
  }

  /// Converts the tile to a plain map for JSON storage. The icon can't be
  /// stored directly, so we keep its code point and font family and rebuild
  /// the [IconData] on load.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'ttsPhrase': ttsPhrase,
    'iconCodePoint': icon.codePoint,
    'iconFontFamily': icon.fontFamily,
    'colorTheme': colorTheme,
    'imageUrl': imageUrl,
  };

  /// Rebuilds a tile from stored JSON. Returns null if a required field is
  /// missing or malformed, so one bad record can't crash the whole board.
  static CommTile? fromJson(Map<String, dynamic> json) {
    final Object? id = json['id'];
    final Object? label = json['label'];
    final Object? ttsPhrase = json['ttsPhrase'];
    final Object? codePoint = json['iconCodePoint'];
    final Object? colorTheme = json['colorTheme'];
    if (id is! String ||
        label is! String ||
        ttsPhrase is! String ||
        codePoint is! int ||
        colorTheme is! String) {
      return null;
    }

    return CommTile(
      id: id,
      label: label,
      ttsPhrase: ttsPhrase,
      icon: IconData(
        codePoint,
        fontFamily: json['iconFontFamily'] as String? ?? 'MaterialIcons',
      ),
      colorTheme: colorTheme,
      imageUrl: json['imageUrl'] as String?,
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

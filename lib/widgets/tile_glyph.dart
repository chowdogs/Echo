import 'package:flutter/material.dart';

/// Renders a tile's visual: an ARASAAC pictogram when [imageUrl] is set,
/// otherwise the Material [icon].
///
/// The icon is always the safety net — while a pictogram is downloading, or if
/// it fails to load (offline, bad URL), the icon shows instead, so a tile is
/// never blank.
class TileGlyph extends StatelessWidget {
  const TileGlyph({
    super.key,
    required this.imageUrl,
    required this.icon,
    required this.iconSize,
    required this.color,
  });

  final String? imageUrl;
  final IconData icon;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Icon(icon, size: iconSize, color: color);
    if (imageUrl == null) return fallback;

    return Image.network(
      imageUrl!,
      // Pictograms are ~square with transparent padding; contain keeps them
      // whole inside the chip.
      fit: BoxFit.contain,
      width: iconSize * 1.4,
      height: iconSize * 1.4,
      gaplessPlayback: true,
      loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? p) {
        if (p == null) return child;
        return SizedBox(
          width: iconSize,
          height: iconSize,
          child: Center(
            child: SizedBox(
              width: iconSize * 0.6,
              height: iconSize * 0.6,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Echo's semantic colour tokens, as a [ThemeExtension] so they can flip
/// between light and dark at runtime.
///
/// The brand stays constant across both modes — the same cool cyan→indigo —
/// while the neutrals invert. Foreground [accent] and [danger] are part of the
/// palette rather than fixed constants because a bright cyan that reads well
/// on dark slate is too pale to sit as text on a white card.
///
/// Contrast is treated as a feature, not a finish: this is an accessibility
/// tool, and a card that melts into its background is a defect for a user with
/// low vision or a phone in sunlight. Every text pairing below clears WCAG AA,
/// and [border] is deliberately dark enough to be seen rather than felt.
@immutable
class EchoColors extends ThemeExtension<EchoColors> {
  const EchoColors({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.danger,
    required this.shadow,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color text;
  final Color muted;

  /// Foreground accent — safe to use as icon/text tint on [surface].
  final Color accent;

  /// Foreground danger — safe as text/icon tint. The filled emergency button
  /// uses [kDangerGradient] instead, which is mode-independent.
  final Color danger;

  /// Base shadow colour. Dark mode shadows are near-black and tighter; light
  /// mode uses a blue-tinted shade so cards feel lifted rather than dirty.
  final Color shadow;

  /// Lets widgets pick a treatment that only works in one mode — a tint that
  /// must lighten on dark and darken on light, for instance.
  final bool isDark;

  static EchoColors of(BuildContext context) =>
      Theme.of(context).extension<EchoColors>()!;

  /// Lifts a card off the canvas. Two layers: a tight contact shadow plus a
  /// wider ambient one, which reads as depth instead of a grey smudge.
  List<BoxShadow> elevation([double strength = 1]) => <BoxShadow>[
    BoxShadow(
      color: shadow.withValues(alpha: (isDark ? 0.34 : 0.07) * strength),
      blurRadius: 2 * strength,
      offset: Offset(0, 1 * strength),
    ),
    BoxShadow(
      color: shadow.withValues(alpha: (isDark ? 0.26 : 0.06) * strength),
      blurRadius: 14 * strength,
      offset: Offset(0, 6 * strength),
    ),
  ];

  /// Blends [tint] into the card surface at a strength that stays legible in
  /// both modes — the basis for colour-coded tiles that are scannable without
  /// becoming saturated blocks.
  Color tintedSurface(Color tint, {double strength = 1}) =>
      Color.alphaBlend(
        tint.withValues(alpha: (isDark ? 0.16 : 0.10) * strength),
        surface,
      );

  @override
  EchoColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? border,
    Color? text,
    Color? muted,
    Color? accent,
    Color? danger,
    Color? shadow,
    bool? isDark,
  }) {
    return EchoColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      border: border ?? this.border,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  EchoColors lerp(covariant EchoColors? other, double t) {
    if (other == null) return this;
    return EchoColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Dark mode — a deeper, cleaner slate than a mid-grey, so the brand cyan and
/// the category colours have something to glow against.
const EchoColors kDarkColors = EchoColors(
  background: Color(0xFF0C111C),
  surface: Color(0xFF161E2E),
  surfaceHigh: Color(0xFF212C42),
  border: Color(0xFF32415C),
  text: Color(0xFFF3F7FD),
  muted: Color(0xFF9DABC2),
  accent: Color(0xFF4CC4FB),
  danger: Color(0xFFFF5A74),
  shadow: Color(0xFF000000),
  isDark: true,
);

/// Light mode — a cool near-white canvas with pure-white cards. The canvas is
/// a step darker than the card on purpose: the old palette put #FFF cards on a
/// #EEF3FA ground with a near-invisible border, and the cards disappeared.
const EchoColors kLightColors = EchoColors(
  background: Color(0xFFEFF3F9),
  surface: Color(0xFFFFFFFF),
  surfaceHigh: Color(0xFFE6EDF7),
  border: Color(0xFFCBD6E6),
  text: Color(0xFF0F1724),
  muted: Color(0xFF53627A),
  accent: Color(0xFF0369A1),
  danger: Color(0xFFD01539),
  shadow: Color(0xFF1E3A5F),
  isDark: false,
);

/// Cool cyan → indigo sweep used for the wordmark, landing CTA, and logo mark.
/// Constant across modes — it always sits on its own fill under white text.
const LinearGradient kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[Color(0xFF38BDF8), Color(0xFF6366F1)],
);

const LinearGradient kDangerGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[Color(0xFFF43F5E), Color(0xFFDC2626)],
);

/// Corner radii, as one scale rather than a different number per widget.
abstract final class EchoRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
}

ThemeData buildEchoTheme(EchoColors colors, Brightness brightness) {
  final ThemeData base = ThemeData(brightness: brightness, useMaterial3: true);

  // Plus Jakarta Sans: geometric enough to read as a contemporary product,
  // neutral enough to suit an adult using an assistive tool. google_fonts
  // falls back to the platform face if it cannot be fetched, so an offline
  // first launch degrades rather than failing.
  final TextTheme typography = GoogleFonts.plusJakartaSansTextTheme(
    base.textTheme,
  ).apply(bodyColor: colors.text, displayColor: colors.text);

  return base.copyWith(
    scaffoldBackgroundColor: colors.background,
    extensions: <ThemeExtension<dynamic>>[colors],
    colorScheme: base.colorScheme.copyWith(
      brightness: brightness,
      surface: colors.surface,
      primary: colors.accent,
      onPrimary: Colors.white,
      error: colors.danger,
    ),
    // Tighter tracking on the large sizes; AAC labels keep normal spacing so
    // they stay easy to read at a glance.
    textTheme: typography.copyWith(
      displaySmall: typography.displaySmall?.copyWith(
        letterSpacing: -1.2,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: typography.headlineMedium?.copyWith(
        letterSpacing: -0.9,
        fontWeight: FontWeight.w800,
      ),
      headlineSmall: typography.headlineSmall?.copyWith(
        letterSpacing: -0.6,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: typography.titleLarge?.copyWith(
        letterSpacing: -0.4,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: typography.titleMedium?.copyWith(
        letterSpacing: -0.2,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

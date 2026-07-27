import 'package:flutter/material.dart';

/// Echo's semantic colour tokens, as a [ThemeExtension] so they can flip
/// between light and dark at runtime.
///
/// The brand stays constant across both modes — the same cool cyan→indigo the
/// user asked to keep — while the neutrals (background, surface, border, text)
/// invert. Foreground [accent] and [danger] are part of the palette rather
/// than fixed constants because a bright cyan that reads well on dark slate is
/// too pale to sit as text on a white card; light mode uses deeper tones.
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

  static EchoColors of(BuildContext context) =>
      Theme.of(context).extension<EchoColors>()!;

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
    );
  }
}

/// Dark mode — the original deep-slate palette.
const EchoColors kDarkColors = EchoColors(
  background: Color(0xFF121826),
  surface: Color(0xFF1A2233),
  surfaceHigh: Color(0xFF222C40),
  border: Color(0xFF2A3650),
  text: Color(0xFFEEF2F8),
  muted: Color(0xFF97A3B8),
  accent: Color(0xFF38BDF8),
  danger: Color(0xFFF43F5E),
);

/// Light mode — the inverse, keeping the same cool blue cast. Surfaces are
/// near-white with a faint blue tint; the accent deepens to hold contrast on
/// them.
const EchoColors kLightColors = EchoColors(
  background: Color(0xFFEEF3FA),
  surface: Color(0xFFFFFFFF),
  surfaceHigh: Color(0xFFE7EEF7),
  border: Color(0xFFD6E0EE),
  text: Color(0xFF16202E),
  muted: Color(0xFF5C6B80),
  accent: Color(0xFF0284C7),
  danger: Color(0xFFE11D48),
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

ThemeData buildEchoTheme(EchoColors colors, Brightness brightness) {
  final ThemeData base = ThemeData(brightness: brightness, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: colors.background,
    extensions: <ThemeExtension<dynamic>>[colors],
    colorScheme: base.colorScheme.copyWith(
      brightness: brightness,
      surface: colors.surface,
      primary: colors.accent,
      onPrimary: brightness == Brightness.dark
          ? const Color(0xFF04121C)
          : Colors.white,
      error: colors.danger,
    ),
    textTheme: base.textTheme
        .apply(bodyColor: colors.text, displayColor: colors.text)
        .copyWith(
          // A touch of negative tracking on headings reads as contemporary
          // product design rather than default Material.
          headlineLarge: const TextStyle(letterSpacing: -0.8),
          titleLarge: const TextStyle(letterSpacing: -0.4),
        ),
  );
}

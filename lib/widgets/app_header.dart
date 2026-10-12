import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Echo logo mark: a gradient tile with a soundwave glyph.
///
/// Pulled out as its own widget because it appears both here and on the
/// landing screen, and the two must stay identical.
class EchoLogoMark extends StatelessWidget {
  const EchoLogoMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: kBrandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.38),
            blurRadius: size * 0.45,
            offset: Offset(0, size * 0.16),
          ),
        ],
      ),
      child: Icon(
        Icons.graphic_eq_rounded,
        size: size * 0.56,
        color: Colors.white,
      ),
    );
  }
}

/// Fixed header pinned to the top of the shell.
///
/// Sits directly on the canvas with no rule beneath it. A hard border here
/// competed with the tile grid immediately below; letting the board start
/// without a dividing line makes it read as the page rather than as content
/// stuffed under a chrome bar.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return ColoredBox(
      color: c.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
          child: Row(
            children: <Widget>[
              const EchoLogoMark(size: 34),
              const SizedBox(width: 11),
              ShaderMask(
                shaderCallback: (Rect bounds) =>
                    kBrandGradient.createShader(bounds),
                child: const Text(
                  'Echo',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              const _ReadyPill(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A calm signal that the board is live — deliberately not a control, so
/// there is nothing here to tap by mistake.
class _ReadyPill extends StatelessWidget {
  const _ReadyPill();

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    const Color live = Color(0xFF16A34A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: live.withValues(alpha: c.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: live,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'Ready',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Echo logo mark: a small gradient tile with a soundwave glyph.
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
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(
        Icons.graphic_eq_rounded,
        size: size * 0.58,
        color: Colors.white,
      ),
    );
  }
}

/// Fixed header pinned to the top of the shell.
///
/// Holds the brand on the left and a lightweight "ready" status on the right
/// in place of the removed Edit control — a calm signal that the board is live
/// rather than another thing to tap by mistake.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
          child: Row(
            children: <Widget>[
              const EchoLogoMark(),
              const SizedBox(width: 12),
              ShaderMask(
                shaderCallback: (Rect bounds) =>
                    kBrandGradient.createShader(bounds),
                child: const Text(
                  'Echo',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
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

class _ReadyPill extends StatelessWidget {
  const _ReadyPill();

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            'Ready',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.muted,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

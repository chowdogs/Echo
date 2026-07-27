import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// The first screen the app opens on.
///
/// A calm brand moment, not a marketing splash: the mark, the name, a plain
/// statement of what Echo does, and one clear way forward. Everything is
/// centred and generously spaced so it reads as considered rather than busy.
class LandingView extends StatelessWidget {
  const LandingView({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final bool animate = !MediaQuery.disableAnimationsOf(context);
    final EchoColors c = EchoColors.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: <Widget>[
          // A single soft glow up top gives the flat dark surface some depth
          // without tipping into decoration for its own sake.
          const _TopGlow(),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Fill the viewport on a normal screen (the Spacers spread the
                // content out); scroll instead of overflowing on a short one.
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        child: _EntranceFade(
                          animate: animate,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              const Spacer(flex: 3),
                              const Center(child: EchoLogoMark(size: 76)),
                              const SizedBox(height: 28),
                              ShaderMask(
                                shaderCallback: (Rect bounds) =>
                                    kBrandGradient.createShader(bounds),
                                child: const Text(
                                  'Echo',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 52,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'A calm, tap-to-speak assistant for anyone whose voice '
                                'needs a hand — at any age, for any reason.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  color: c.muted,
                                ),
                              ),
                              const Spacer(flex: 2),
                              const _FeatureRow(),
                              const Spacer(flex: 3),
                              _StartButton(onStart: onStart),
                              const SizedBox(height: 16),
                              Text(
                                'Works offline · No account needed',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: c.muted,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopGlow extends StatelessWidget {
  const _TopGlow();

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Positioned(
      top: -140,
      left: 0,
      right: 0,
      child: Container(
        height: 320,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: <Color>[
              // A cyan wash so the glow keeps its colour in both modes.
              const Color(0xFF38BDF8).withValues(alpha: 0.18),
              c.background.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        Expanded(
          child: _Feature(
            icon: Icons.grid_view_rounded,
            label: 'Speak in\none tap',
          ),
        ),
        Expanded(
          child: _Feature(icon: Icons.sos_rounded, label: 'Instant\nemergency'),
        ),
        Expanded(
          child: _Feature(
            icon: Icons.insights_rounded,
            label: 'Track for\ncaregivers',
          ),
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Column(
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Icon(icon, color: c.accent, size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, height: 1.3, color: c.muted),
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Get started',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onStart,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: kBrandGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// One-shot fade-and-rise on first paint. Skipped entirely when the platform
/// asks for reduced motion.
class _EntranceFade extends StatelessWidget {
  const _EntranceFade({required this.child, required this.animate});

  final Widget child;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (!animate) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 24),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

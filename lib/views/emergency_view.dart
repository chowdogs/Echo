import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/tile_state.dart';
import '../theme/app_theme.dart';
import '../widgets/section_intro.dart';

/// Crisis view.
///
/// Deliberately holds exactly one control. In a crisis every extra element on
/// screen is something to rule out first, so the layout stays as close to a
/// single unmissable target as it can get.
class EmergencyView extends StatelessWidget {
  const EmergencyView({super.key});

  static const double _maxButtonSize = 236;
  static const double _minButtonSize = 150;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: SectionIntro(
            title: 'Emergency',
            subtitle: 'Hold the button to send an alert',
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Reserve room for the caption before sizing the button, so a
                // short screen shrinks the circle instead of overflowing.
                const double captionAllowance = 104;
                final double size = math
                    .min(
                      _maxButtonSize,
                      math.min(
                        constraints.maxHeight - captionAllowance,
                        constraints.maxWidth,
                      ),
                    )
                    .clamp(_minButtonSize, _maxButtonSize);

                return _HoldToActivate(size: size);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// A press-and-hold SOS button.
///
/// A single accidental tap must never fire an emergency alert, so activation
/// requires holding for a full [_holdDuration]. A ring sweeps around the button
/// as the hold progresses and only completes — triggering the alert — once the
/// ring closes. Letting go early rewinds it.
class _HoldToActivate extends StatefulWidget {
  const _HoldToActivate({required this.size});

  final double size;

  @override
  State<_HoldToActivate> createState() => _HoldToActivateState();
}

class _HoldToActivateState extends State<_HoldToActivate>
    with SingleTickerProviderStateMixin {
  static const Duration _holdDuration = Duration(seconds: 2);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _holdDuration,
  )..addStatusListener(_onStatus);

  bool _holding = false;
  bool _activated = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_activated) {
      _activate();
    }
  }

  void _activate() {
    setState(() {
      _activated = true;
      _holding = false;
    });
    context.read<TileState>().speak(kEmergencyTile);
    HapticFeedback.heavyImpact();

    // Re-arm after a moment so the button can be used again.
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      _controller.reset();
      setState(() => _activated = false);
    });
  }

  void _onDown() {
    if (_activated) return;
    setState(() => _holding = true);
    HapticFeedback.selectionClick();
    _controller.forward(from: _controller.value);
  }

  void _onUp() {
    if (_activated || !_holding) return;
    setState(() => _holding = false);
    // Rewind quickly rather than snapping, so a near-miss reads as "not yet".
    if (_controller.status != AnimationStatus.completed) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Semantics(
          button: true,
          label: 'Emergency. Hold for two seconds to send an alert.',
          // Assistive-tech activation is already deliberate, so honour a
          // direct tap there without requiring a physical hold.
          onTap: _activated ? null : _activate,
          excludeSemantics: true,
          child: Listener(
            onPointerDown: (_) => _onDown(),
            onPointerUp: (_) => _onUp(),
            onPointerCancel: (_) => _onUp(),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, _) {
                return _buildButton(widget.size);
              },
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 300,
          child: Text(
            _activated
                ? 'Alert sent. Your caretakers have been notified.'
                : 'Press and hold for 2 seconds to send an urgent alert.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: _activated ? c.accent : c.muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(double size) {
    final double progress = _controller.value;
    // A gentle grow while held gives the press some weight.
    final double scale = _holding ? 1.03 : 1.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // The progress ring rides just outside the circle.
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress,
              track: const Color(0xFFF43F5E).withValues(alpha: 0.18),
              fill: const Color(0xFFF43F5E),
            ),
          ),
          AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: size - 26,
              height: size - 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: kDangerGradient,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(
                      0xFFF43F5E,
                    ).withValues(alpha: _holding ? 0.55 : 0.4),
                    blurRadius: _holding ? 40 : 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    _activated ? Icons.check_rounded : Icons.sos_rounded,
                    size: size * 0.26,
                    color: Colors.white,
                  ),
                  SizedBox(height: size * 0.03),
                  Text(
                    _activated
                        ? 'SENT'
                        : (_holding ? 'KEEP HOLDING' : 'HOLD FOR HELP'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: size * 0.08,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  static const double _stroke = 7;

  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - _stroke) / 2;

    final Paint trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final Paint fillPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.fill != fill || old.track != track;
}

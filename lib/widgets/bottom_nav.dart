import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/tile_state.dart';
import '../theme/app_theme.dart';

/// Persistent bottom navigation.
///
/// Layout mirrors the requested order — Speak on the far left, Emergency
/// raised in the dead centre, and Stats then Settings on the right with
/// Settings anchored rightmost. Equal [Expanded] flanks keep the emergency
/// button truly centred regardless of how many items sit on each side, and
/// every label lives in a [FittedBox] so nothing overflows on a small phone.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  static const double _barHeight = 64;

  @override
  Widget build(BuildContext context) {
    final EchoTab active = context.select<TileState, EchoTab>(
      (TileState s) => s.activeTab,
    );

    void go(EchoTab tab) => context.read<TileState>().setActiveTab(tab);

    final EchoColors c = EchoColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _barHeight,
          child: Row(
            children: <Widget>[
              // Left flank: Speak.
              Expanded(
                child: _NavItem(
                  icon: Icons.record_voice_over_rounded,
                  label: 'Speak',
                  isActive: active == EchoTab.speak,
                  onTap: () => go(EchoTab.speak),
                ),
              ),
              // Centre: the raised SOS button.
              _EmergencyButton(
                barHeight: _barHeight,
                isActive: active == EchoTab.emergency,
                onTap: () => go(EchoTab.emergency),
              ),
              // Right flank: Settings.
              Expanded(
                child: _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isActive: active == EchoTab.settings,
                  onTap: () => go(EchoTab.settings),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final Color color = isActive ? c.accent : c.muted;

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 23, color: color),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The raised centre button. Larger than the flanking items and the only red
/// element in the app, so it stays unmistakable.
///
/// A [Stack] with `Clip.none` lets the circle rise above the bar without
/// inflating the row height (which would otherwise overflow), giving the
/// familiar docked-action look.
class _EmergencyButton extends StatelessWidget {
  const _EmergencyButton({
    required this.barHeight,
    required this.isActive,
    required this.onTap,
  });

  final double barHeight;
  final bool isActive;
  final VoidCallback onTap;

  static const double _diameter = 54;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Semantics(
      button: true,
      selected: isActive,
      label: 'Emergency',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 76,
          height: barHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Positioned(
                top: -16,
                child: Container(
                  width: _diameter,
                  height: _diameter,
                  decoration: BoxDecoration(
                    gradient: kDangerGradient,
                    shape: BoxShape.circle,
                    // Matches the bar surface so the circle reads as punched
                    // through it in either mode.
                    border: Border.all(color: c.surface, width: 4),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: c.danger.withValues(alpha: isActive ? 0.6 : 0.4),
                        blurRadius: isActive ? 22 : 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sos_rounded,
                    size: 26,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                bottom: 7,
                child: Text(
                  'Emergency',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: isActive ? c.danger : c.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

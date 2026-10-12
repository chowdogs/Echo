import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/tile_state.dart';
import '../theme/app_theme.dart';

/// Persistent bottom navigation.
///
/// Speak on the left, Settings on the right, and Emergency raised in the dead
/// centre. Equal [Expanded] flanks keep the emergency button truly centred,
/// and every label lives in a [FittedBox] so nothing overflows on a small
/// phone.
///
/// The active destination now gets a filled pill behind it rather than only a
/// colour change: colour alone is a weak signal for a user with a colour
/// vision deficiency, and this board is navigated by people who cannot afford
/// to guess where they are.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  static const double _barHeight = 66;

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
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.shadow.withValues(alpha: c.isDark ? 0.4 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _barHeight,
          child: Row(
            children: <Widget>[
              Expanded(
                child: _NavItem(
                  icon: Icons.record_voice_over_rounded,
                  label: 'Speak',
                  isActive: active == EchoTab.speak,
                  onTap: () => go(EchoTab.speak),
                ),
              ),
              _EmergencyButton(
                barHeight: _barHeight,
                isActive: active == EchoTab.emergency,
                onTap: () => go(EchoTab.emergency),
              ),
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
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? c.accent.withValues(alpha: c.isDark ? 0.20 : 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.1,
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
/// inflating the row height, giving the familiar docked-action look.
class _EmergencyButton extends StatelessWidget {
  const _EmergencyButton({
    required this.barHeight,
    required this.isActive,
    required this.onTap,
  });

  final double barHeight;
  final bool isActive;
  final VoidCallback onTap;

  static const double _diameter = 58;

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
          width: 82,
          height: barHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Positioned(
                top: -18,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
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
                        color: c.danger.withValues(
                          alpha: isActive ? 0.58 : 0.34,
                        ),
                        blurRadius: isActive ? 24 : 16,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sos_rounded,
                    size: 27,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                child: Text(
                  'Emergency',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
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

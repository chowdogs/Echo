import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/controller_state.dart';
import '../theme/app_theme.dart';

/// The in-app emergency alert a guardian sees when one of their patients
/// triggers SOS.
///
/// It sits above everything else in the shell and cannot be scrolled away —
/// an emergency should interrupt whatever the guardian was doing. Dismissing
/// is deliberately an explicit tap rather than a swipe or a timeout, so an
/// alert is never lost to a stray gesture.
class SosAlertBanner extends StatelessWidget {
  const SosAlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Absent entirely for users who have never paired with a patient.
    ControllerState? controller;
    try {
      controller = context.watch<ControllerState>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }

    if (!controller.hasAlerts) return const SizedBox.shrink();

    final EchoColors c = EchoColors.of(context);
    final PatientAlert latest = controller.alerts.last;
    final int extra = controller.alerts.length - 1;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
          color: c.danger,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.danger.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.sos_rounded,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      extra > 0
                          ? 'Emergency — ${extra + 1} alerts'
                          : 'Emergency alert',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${latest.patient.displayName} · '
                      '${TimeOfDay.fromDateTime(latest.event.at).format(context)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () =>
                    context.read<ControllerState>().dismissAllAlerts(),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

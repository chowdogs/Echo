import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The title + subtitle block each view opens with.
///
/// The global [AppHeader] carries the brand; this carries the "where am I"
/// context, so the two never duplicate each other.
class SectionIntro extends StatelessWidget {
  const SectionIntro({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            color: c.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 14.5, height: 1.35, color: c.muted),
        ),
      ],
    );
  }
}

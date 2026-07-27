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
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: c.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 14, color: c.muted)),
      ],
    );
  }
}

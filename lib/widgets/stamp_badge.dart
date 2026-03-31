import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

class StampBadge extends StatelessWidget {
  final String text;
  final double size;
  final bool animate;

  const StampBadge({
    super.key,
    required this.text,
    this.size = 44,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primary, width: 2.5),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: AppTheme.condensedBold.copyWith(
          color: AppTheme.primary,
          fontSize: size * 0.26,
          letterSpacing: 0.5,
        ),
        textAlign: TextAlign.center,
      ),
    );

    if (animate) {
      badge = Opacity(
        opacity: 0.85,
        child: badge
            .animate(onPlay: (c) => c.forward())
            .scale(
              begin: const Offset(2.5, 2.5),
              end: const Offset(1.0, 1.0),
              duration: 450.ms,
              curve: const Cubic(0.22, 1, 0.36, 1),
            )
            .rotate(
              begin: -8 / 360,
              end: 0,
              duration: 450.ms,
              curve: const Cubic(0.22, 1, 0.36, 1),
            )
            .fadeIn(duration: 200.ms),
      );
    } else {
      badge = Opacity(opacity: 0.85, child: badge);
    }

    return badge;
  }
}

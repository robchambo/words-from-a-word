// lib/widgets/trophy_badge.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TrophyBadge extends StatelessWidget {
  final String title;
  final bool unlocked;
  final VoidCallback? onTap;
  const TrophyBadge({
    super.key, required this.title, required this.unlocked, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? AppTheme.primary : AppTheme.muted;
    return InkResponse(
      onTap: onTap, radius: 48,
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(
              unlocked ? Icons.emoji_events : Icons.lock,
              color: AppTheme.background, size: 28,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 80,
            child: Text(title, textAlign: TextAlign.center,
                style: AppTheme.condensedLabel),
          ),
        ],
      ),
    );
  }
}

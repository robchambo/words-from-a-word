import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LetterTileWidget extends StatelessWidget {
  final String letter;
  final bool isSelected;
  final bool isUsed;
  final VoidCallback onTap;

  const LetterTileWidget({
    super.key,
    required this.letter,
    required this.isSelected,
    required this.isUsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUsed ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isUsed ? 0.35 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: 48,
          height: 48,
          transform: Matrix4.identity()
            // ignore: deprecated_member_use
            ..scale(isSelected ? 1.08 : 1.0)
            // ignore: deprecated_member_use
            ..translate(0.0, isSelected ? -2.0 : 0.0),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.background : AppTheme.tileBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.7)
                  : AppTheme.border.withValues(alpha: 0.6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                offset: Offset(0, isSelected ? 6 : 2),
                blurRadius: isSelected ? 16 : 6,
                color: AppTheme.foreground
                    .withValues(alpha: isSelected ? 0.28 : 0.18),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            letter.toUpperCase(),
            style: AppTheme.tileLabel,
          ),
        ),
      ),
    );
  }
}

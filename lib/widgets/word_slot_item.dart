import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/game_state.dart';
import '../theme/app_theme.dart';

class WordSlotItem extends StatelessWidget {
  final TargetWord targetWord;
  final bool justFound;

  const WordSlotItem({
    super.key,
    required this.targetWord,
    this.justFound = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(targetWord.length, (i) {
          final isRevealed = targetWord.isFound;
          final letter =
              isRevealed ? targetWord.word[i].toUpperCase() : '';

          Widget slot = Container(
            width: 22,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isRevealed
                      ? AppTheme.slotFilled
                      : AppTheme.slotEmpty,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              letter,
              style: AppTheme.condensedBold.copyWith(
                fontSize: 13,
              ),
            ),
          );

          if (justFound && isRevealed) {
            slot = slot
                .animate(delay: (i * 50).ms)
                .scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.12, 1.12),
                  duration: 150.ms,
                )
                .then()
                .scale(
                  begin: const Offset(1.12, 1.12),
                  end: const Offset(1.0, 1.0),
                  duration: 150.ms,
                );
          }

          return slot;
        }),
      ),
    );
  }
}

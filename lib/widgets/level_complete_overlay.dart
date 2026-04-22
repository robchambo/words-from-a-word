import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/language_mode.dart';
import '../l10n/strings_ru.dart';
import '../l10n/strings_en.dart';
import '../theme/app_theme.dart';

class LevelCompleteOverlay extends StatelessWidget {
  final int score;
  final int wordsFound;
  final LanguageMode languageMode;
  final VoidCallback onNextLevel;
  final int? previousBest;
  final bool isNewBest;

  const LevelCompleteOverlay({
    super.key,
    required this.score,
    required this.wordsFound,
    required this.languageMode,
    required this.onNextLevel,
    this.previousBest,
    this.isNewBest = false,
  });

  bool get _isRu => languageMode == LanguageMode.russian;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.foreground.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 8),
                blurRadius: 32,
                color: AppTheme.foreground.withValues(alpha: 0.3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Confetti
              SizedBox(
                height: 60,
                child: _Confetti(),
              ),
              const SizedBox(height: 8),
              Text(
                _isRu
                    ? StringsRu.levelCompleteTitle
                    : StringsEn.levelCompleteTitle,
                style: AppTheme.displayLarge.copyWith(
                  color: AppTheme.primary,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$wordsFound ${_isRu ? StringsRu.wordsFoundLabel : StringsEn.wordsFoundLabel}',
                style: AppTheme.condensedBold.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '$score ${_isRu ? StringsRu.scoreLabel : StringsEn.scoreLabel}',
                style: AppTheme.displayMedium.copyWith(
                  color: AppTheme.accent,
                ),
              ),
              if (isNewBest) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isRu ? StringsRu.newBestTag : StringsEn.newBestTag,
                    style: AppTheme.condensedBold.copyWith(
                      color: AppTheme.background,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ] else if (previousBest != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${_isRu ? StringsRu.levelPickerBestScore : StringsEn.levelPickerBestScore}: $previousBest',
                  style: AppTheme.condensedLabel.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onNextLevel,
                child: Text(
                  _isRu
                      ? StringsRu.nextLevelButton
                      : StringsEn.nextLevelButton,
                ),
              ),
            ],
          ),
        )
            .animate(onPlay: (c) => c.forward())
            .fadeIn(duration: 400.ms)
            .scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.0, 1.0),
              duration: 400.ms,
              curve: Curves.elasticOut,
            ),
      ),
    );
  }
}

class _Confetti extends StatelessWidget {
  static final _rng = Random();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(18, (i) {
        final color = [
          AppTheme.primary,
          AppTheme.accent,
          AppTheme.foreground,
        ][i % 3];
        final left = _rng.nextDouble() * 280;
        final size = 6.0 + _rng.nextDouble() * 6;

        return Positioned(
          left: left,
          top: 0,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          )
              .animate(onPlay: (c) => c.forward())
              .moveY(
                begin: 0,
                end: 80,
                duration: 1200.ms,
                delay: (i * 40).ms,
                curve: Curves.easeIn,
              )
              .rotate(
                begin: 0,
                end: 1,
                duration: 1200.ms,
                delay: (i * 40).ms,
              )
              .fadeOut(
                delay: 800.ms,
                duration: 400.ms,
              ),
        );
      }),
    );
  }
}

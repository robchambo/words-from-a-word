import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/rewards_provider.dart';
import '../theme/app_theme.dart';

/// Horizontal band showing the player's lifetime score (primary colour) and
/// current streak (accent colour). Stateless — all data read from
/// [RewardsProvider].
class LifetimeScoreBand extends StatelessWidget {
  final LanguageMode mode;

  const LifetimeScoreBand({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final rewards = context.watch<RewardsProvider>();
    final isRu = mode == LanguageMode.russian;
    final score = rewards.lifetimeScore[mode] ?? 0;
    final streak = rewards.streakCount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ScorePill(
            value: score,
            label: isRu
                ? StringsRu.lifetimeScoreLabel
                : StringsEn.lifetimeScoreLabel,
            color: AppTheme.primary,
          ),
          Container(
            width: 1,
            height: 36,
            color: AppTheme.border.withValues(alpha: 0.6),
          ),
          _ScorePill(
            value: streak,
            label: isRu
                ? StringsRu.streakDaysLabel
                : StringsEn.streakDaysLabel,
            color: AppTheme.accent,
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _ScorePill({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: AppTheme.condensedBold.copyWith(
            fontSize: 24,
            color: color,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: AppTheme.condensedLabel.copyWith(fontSize: 9),
        ),
      ],
    );
  }
}

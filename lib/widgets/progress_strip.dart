import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/rewards_provider.dart';
import '../theme/app_theme.dart';

class ProgressStrip extends StatelessWidget {
  final LanguageMode mode;
  const ProgressStrip({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final isRu = mode == LanguageMode.russian;
    final r = context.watch<RewardsProvider>();
    final bonus = r.bonusWordCounter;
    final banked = r.freeHintSlot + r.purchasedHintCount;

    // Hide strip if nothing to show.
    if (bonus == 0 && banked == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRu ? StringsRu.bonusCounterLabel : StringsEn.bonusCounterLabel,
                  style: AppTheme.condensedLabel,
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (bonus / 10.0).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppTheme.muted,
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.accent),
                  ),
                ),
                Text('$bonus / 10', style: AppTheme.condensedLabel),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb,
                    color: AppTheme.background, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$banked',
                  style: AppTheme.condensedBold
                      .copyWith(color: AppTheme.background),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

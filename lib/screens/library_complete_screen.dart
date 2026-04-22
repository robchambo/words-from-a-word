import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../models/level_picker_filter.dart';
import '../providers/rewards_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/grid_paper_background.dart';
import 'level_picker_screen.dart';

class LibraryCompleteScreen extends StatelessWidget {
  final LanguageMode mode;

  const LibraryCompleteScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final isRu = mode == LanguageMode.russian;
    final rewards = context.watch<RewardsProvider>();
    final lifetime = rewards.lifetimeScore[mode] ?? 0;
    final streak = rewards.streakCount;

    return Scaffold(
      body: GridPaperBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title
                  Text(
                    isRu
                        ? StringsRu.libraryCompleteTitle
                        : StringsEn.libraryCompleteTitle,
                    textAlign: TextAlign.center,
                    style: AppTheme.displayLarge.copyWith(
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Body text
                  Text(
                    isRu
                        ? StringsRu.libraryCompleteBody
                        : StringsEn.libraryCompleteBody,
                    textAlign: TextAlign.center,
                    style: AppTheme.condensedLabel.copyWith(
                      fontSize: 14,
                      letterSpacing: 0.5,
                      height: 1.5,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Lifetime score row
                  _StatRow(
                    label: isRu
                        ? StringsRu.lifetimeScoreLabel
                        : StringsEn.lifetimeScoreLabel,
                    value: '$lifetime',
                    valueColor: AppTheme.accent,
                  ),
                  const SizedBox(height: 16),

                  // Streak count row
                  _StatRow(
                    label: isRu
                        ? StringsRu.streakDaysLabel
                        : StringsEn.streakDaysLabel,
                    value: '$streak',
                    valueColor: AppTheme.accent,
                  ),
                  const SizedBox(height: 48),

                  // Replay levels button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LevelPickerScreen(
                              mode: mode,
                              filter: LevelPickerFilter.completedOnly,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.primaryFg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: Text(
                        isRu
                            ? StringsRu.libraryCompleteReplay
                            : StringsEn.libraryCompleteReplay,
                        style: AppTheme.condensedBold.copyWith(
                          color: AppTheme.primaryFg,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Close button
                  TextButton(
                    onPressed: () {
                      Navigator.popUntil(context, (r) => r.isFirst);
                    },
                    child: Text(
                      isRu
                          ? StringsRu.libraryCompleteClose
                          : StringsEn.libraryCompleteClose,
                      style: AppTheme.condensedBold.copyWith(
                        color: AppTheme.mutedFg,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTheme.condensedLabel.copyWith(
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
        Text(
          value,
          style: AppTheme.condensedBold.copyWith(
            fontSize: 22,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

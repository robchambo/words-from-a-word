import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';

enum LevelPickerTileState { locked, unlocked, inProgress, completed }

class LevelPickerTile extends StatelessWidget {
  final int levelId;
  final LevelPickerTileState state;
  final int? bestScore;
  final LanguageMode mode;
  final VoidCallback? onTap;

  const LevelPickerTile({
    super.key,
    required this.levelId,
    required this.state,
    required this.bestScore,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRu = mode == LanguageMode.russian;
    final isLocked = state == LevelPickerTileState.locked;
    final color = isLocked ? AppTheme.muted : AppTheme.primary;
    return InkResponse(
      onTap: isLocked ? null : onTap,
      radius: 40,
      child: SizedBox(
        width: 64,
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                '$levelId',
                style: AppTheme.tileLabel.copyWith(color: AppTheme.background),
              ),
            ),
            if (state == LevelPickerTileState.completed && bestScore != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${isRu ? StringsRu.levelPickerBestScore : StringsEn.levelPickerBestScore} $bestScore',
                  style: AppTheme.condensedLabel,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

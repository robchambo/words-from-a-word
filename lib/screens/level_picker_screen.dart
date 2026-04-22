import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/level_loader.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../models/level_picker_filter.dart';
import '../providers/game_provider.dart';
import '../providers/rewards_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/level_picker_tile.dart';
import 'game_screen.dart';

class LevelPickerScreen extends StatelessWidget {
  final LanguageMode mode;
  final LevelPickerFilter filter;

  const LevelPickerScreen({
    super.key,
    required this.mode,
    this.filter = LevelPickerFilter.all,
  });

  @override
  Widget build(BuildContext context) {
    final isRu = mode == LanguageMode.russian;
    final rewards = context.watch<RewardsProvider>();
    final librarySize = LevelLoader.librarySize(mode);
    final highest = rewards.highestCompletedLevel[mode] ?? 0;

    final levels = List<int>.generate(librarySize, (i) => i + 1).where((id) {
      if (filter == LevelPickerFilter.completedOnly) return id <= highest;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.foreground,
        title: Text(
          isRu ? StringsRu.levelPickerTitle : StringsEn.levelPickerTitle,
          style: AppTheme.condensedBold,
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: levels.length,
        itemBuilder: (ctx, i) {
          final id = levels[i];
          final isCompleted = id <= highest;
          final isLocked =
              filter == LevelPickerFilter.all && id > highest + 1;
          final tileState = isLocked
              ? LevelPickerTileState.locked
              : isCompleted
                  ? LevelPickerTileState.completed
                  : LevelPickerTileState.unlocked;
          final best = rewards.levelBestScore[mode]?[id];
          return LevelPickerTile(
            levelId: id,
            state: tileState,
            bestScore: best,
            mode: mode,
            onTap: isLocked
                ? null
                : () {
                    final isReplay = filter == LevelPickerFilter.completedOnly ||
                        isCompleted;
                    context.read<GameProvider>().startGame(
                          mode,
                          levelNumber: id,
                          isReplay: isReplay,
                        );
                    Navigator.of(ctx).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const GameScreen(),
                      ),
                    );
                  },
          );
        },
      ),
    );
  }
}

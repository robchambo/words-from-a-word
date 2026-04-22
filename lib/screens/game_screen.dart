import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../engine/game_engine.dart';
import '../models/game_state.dart';
import '../models/language_mode.dart';
import '../l10n/strings_ru.dart';
import '../l10n/strings_en.dart';
import '../providers/game_provider.dart';
import '../providers/rewards_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/grid_paper_background.dart';
import '../widgets/progress_strip.dart';
import '../widgets/stamp_badge.dart';
import '../widgets/tile_picker.dart';
import '../widgets/word_slots.dart';
import '../widgets/free_hint_earned_overlay.dart';
import '../widgets/level_complete_overlay.dart';
import 'library_complete_screen.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final settings = context.watch<SettingsProvider>();
    final rewards = context.watch<RewardsProvider>();
    final mode = settings.languageMode ?? LanguageMode.russian;
    final isRu = mode == LanguageMode.russian;

    if (!game.isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final state = game.state;

    if (state.libraryComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LibraryCompleteScreen(mode: mode),
          ),
        );
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    final foundCount =
        state.level.targetWords.where((w) => w.isFound && !w.isBonus).length;
    final totalCount = state.level.totalWords;
    final progress = totalCount > 0 ? foundCount / totalCount : 0.0;

    return Scaffold(
      body: GridPaperBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Top bar
                  _buildTopBar(
                    context,
                    state: state,
                    isRu: isRu,
                    mode: mode,
                    foundCount: foundCount,
                    totalCount: totalCount,
                    progress: progress,
                  ),

                  // Replay mode banner
                  if (state.isReplayMode)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: AppTheme.accent.withValues(alpha: 0.25),
                      alignment: Alignment.center,
                      child: Text(
                        isRu
                            ? StringsRu.replayModeBanner
                            : StringsEn.replayModeBanner,
                        style: AppTheme.condensedBold,
                      ),
                    ),

                  // Progress strip (bonus counter + banked hints)
                  ProgressStrip(mode: mode),

                  // Source word
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      state.level.sourceWord.toUpperCase(),
                      style: AppTheme.displayMedium.copyWith(
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  Text(
                    isRu ? StringsRu.subtitle : StringsEn.subtitle,
                    style: AppTheme.condensedLabel,
                  ),

                  Divider(
                    color: AppTheme.border.withValues(alpha: 0.5),
                    height: 16,
                  ),

                  // Word slots (scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: [
                          WordSlots(
                            targetWords: state.level.targetWords,
                            languageMode: mode,
                            lastFoundWord: state.lastFoundWord,
                          ),
                          const SizedBox(height: 16),
                          // Motivational text
                          if (foundCount == 0)
                            Text(
                              isRu
                                  ? StringsRu.startPrompt
                                  : StringsEn.startPrompt,
                              style: AppTheme.displayItalic,
                            ),
                          if (foundCount == totalCount && !state.isLevelComplete)
                            Text(
                              isRu
                                  ? StringsRu.allFoundPrompt
                                  : StringsEn.allFoundPrompt,
                              style: AppTheme.displayItalic,
                            ),
                        ],
                      ),
                    ),
                  ),

                  Divider(
                    color: AppTheme.border.withValues(alpha: 0.5),
                    height: 1,
                  ),

                  // Celebration + hint row
                  _buildStatusRow(context, state, isRu),

                  // Tile picker
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: TilePicker(state: state),
                  ),
                ],
              ),

              // Level complete overlay
              if (state.isLevelComplete)
                Builder(builder: (ctx) {
                  final previousBest =
                      rewards.levelBestScore[mode]?[state.level.levelNumber];
                  final isNewBest =
                      state.pendingScore > (previousBest ?? 0);
                  return LevelCompleteOverlay(
                    score: state.pendingScore,
                    wordsFound: state.foundWords.length,
                    languageMode: mode,
                    previousBest: previousBest,
                    isNewBest: isNewBest,
                    onNextLevel: () async {
                      await game.bankAndAdvance(mode);
                      game.nextLevel(mode);
                    },
                  );
                }),

              FreeHintEarnedOverlay(mode: mode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context, {
    required GameState state,
    required bool isRu,
    required LanguageMode mode,
    required int foundCount,
    required int totalCount,
    required double progress,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.foreground),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),

          // Level stamp + difficulty
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StampBadge(
                text:
                    '${isRu ? StringsRu.levelLabel : StringsEn.levelLabel}\n${state.level.levelNumber}',
                size: 44,
              ),
              Text(
                isRu
                    ? StringsRu.difficultyLabel(state.level.difficulty)
                    : StringsEn.difficultyLabel(state.level.difficulty),
                style: AppTheme.condensedLabel.copyWith(
                  fontSize: 8,
                  color: AppTheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),

          // Progress bar + counter
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.muted,
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.primary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$foundCount / $totalCount ${isRu ? StringsRu.wordsOf : StringsEn.wordsOf}',
                  style: AppTheme.condensedLabel,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isRu
                    ? StringsRu.scoreLabel.toUpperCase()
                    : StringsEn.scoreLabel.toUpperCase(),
                style: AppTheme.condensedLabel,
              ),
              Text(
                '${state.pendingScore}',
                style: AppTheme.condensedBold.copyWith(fontSize: 18),
              )
                  .animate(
                    target: state.pendingScore > 0 ? 1 : 0,
                  )
                  .scale(
                    begin: const Offset(1.3, 1.3),
                    end: const Offset(1.0, 1.0),
                    duration: 300.ms,
                  ),
            ],
          ),

          // Language toggle
          const SizedBox(width: 4),
          _languageToggle(context, mode),
        ],
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, GameState state, bool isRu) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Status message: last found word OR too-common notice
          if (state.lastFoundWord != null)
            Builder(builder: (_) {
              final word = state.lastFoundWord!;
              final isBonus = state.level.targetWords
                  .any((tw) => tw.word == word && tw.isBonus);
              final points = GameEngine.scoreWord(word, isBonus: isBonus);
              return Expanded(
                child: Text(
                  '✓ ${word.toUpperCase()}  +$points',
                  style: AppTheme.condensedBold.copyWith(
                    color: AppTheme.primary,
                    fontSize: 12,
                  ),
                )
                    .animate(onPlay: (c) => c.forward())
                    .slideX(begin: -0.3, end: 0, duration: 200.ms)
                    .fadeIn(duration: 200.ms),
              );
            })
          else if (state.alreadyUsedWord != null)
            Expanded(
              child: Text(
                isRu
                    ? StringsRu.alreadyUsedBonus(state.alreadyUsedInLevel ?? 0)
                    : StringsEn.alreadyUsedBonus(state.alreadyUsedInLevel ?? 0),
                style: AppTheme.condensedLabel.copyWith(
                  color: AppTheme.mutedFg,
                  fontSize: 12,
                ),
              )
                  .animate(onPlay: (c) => c.forward())
                  .slideX(begin: -0.3, end: 0, duration: 200.ms)
                  .fadeIn(duration: 200.ms),
            )
          else if (state.tooCommonWord != null)
            Expanded(
              child: Text(
                isRu ? StringsRu.tooCommonWord : StringsEn.tooCommonWord,
                style: AppTheme.condensedLabel.copyWith(
                  color: AppTheme.mutedFg,
                  fontSize: 12,
                ),
              )
                  .animate(onPlay: (c) => c.forward())
                  .slideX(begin: -0.3, end: 0, duration: 200.ms)
                  .fadeIn(duration: 200.ms),
            )
          else
            const Expanded(child: SizedBox()),

          // Hint button
          Builder(builder: (ctx) {
            final available = ctx.watch<GameProvider>().hintAvailable;
            return GestureDetector(
              onTap: available
                  ? () => ctx.read<GameProvider>().useHint()
                  : null,
              child: Text(
                '💡 ${isRu ? StringsRu.hintButton : StringsEn.hintButton}',
                style: AppTheme.condensedLabel.copyWith(
                  color: available ? AppTheme.accent : AppTheme.mutedFg,
                  fontSize: 11,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _languageToggle(BuildContext context, LanguageMode mode) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _languageSheet(ctx),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(20),
          color: AppTheme.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mode.flagEmoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              mode == LanguageMode.russian ? 'РУ' : 'EN',
              style: AppTheme.condensedLabel.copyWith(
                color: AppTheme.foreground,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageSheet(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('Choose Language / Выберите язык',
              style: AppTheme.displayMedium.copyWith(fontSize: 18)),
          const SizedBox(height: 20),
          _langButton(context, LanguageMode.russian, '🇷🇺', 'Русский',
              AppTheme.primary),
          const SizedBox(height: 12),
          _langButton(context, LanguageMode.english, '🇺🇸', 'English',
              AppTheme.foreground),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _langButton(BuildContext context, LanguageMode mode, String flag,
      String label, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () async {
          final settings = context.read<SettingsProvider>();
          final game = context.read<GameProvider>();
          Navigator.pop(context); // close sheet
          await settings.setLanguageMode(mode);
          await game.startGame(mode);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppTheme.primaryFg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(label,
                style: AppTheme.condensedBold.copyWith(
                  color: AppTheme.primaryFg,
                  fontSize: 16,
                )),
          ],
        ),
      ),
    );
  }
}

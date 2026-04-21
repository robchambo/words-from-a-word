import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/language_mode.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/grid_paper_background.dart';
import '../widgets/rules_modal.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (settings.languageMode == null) {
      return const _LanguagePicker(key: ValueKey('language-picker'));
    }
    return _HomeMain(
      key: const ValueKey('home-main'),
      mode: settings.languageMode!,
    );
  }
}

// ---------------------------------------------------------------------------
// _LanguagePicker — shown on first launch when no language has been chosen
// ---------------------------------------------------------------------------

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridPaperBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),

                  // Title
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Слова ',
                          style: AppTheme.displayLarge.copyWith(
                            color: AppTheme.primary,
                          ),
                        ),
                        TextSpan(
                          text: 'из Слова',
                          style: AppTheme.displayLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Words from a Word',
                    style: AppTheme.condensedLabel.copyWith(
                      fontSize: 12,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Decorative tiles
                  _decorativeTiles(),
                  const SizedBox(height: 40),

                  // Russian play button
                  _playButton(
                    context: context,
                    mode: LanguageMode.russian,
                    label: 'Русский',
                    sublabel: 'Russian',
                    flag: '🇷🇺',
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 16),

                  // English play button
                  _playButton(
                    context: context,
                    mode: LanguageMode.english,
                    label: 'English',
                    sublabel: 'American',
                    flag: '🇺🇸',
                    color: AppTheme.foreground,
                  ),
                  const SizedBox(height: 24),

                  // Rules button
                  TextButton(
                    onPressed: () {
                      final settings = context.read<SettingsProvider>();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => RulesModal(
                          languageMode:
                              settings.languageMode ?? LanguageMode.russian,
                        ),
                      );
                    },
                    child: Text(
                      'Rules / Правила',
                      style: AppTheme.condensedBold.copyWith(
                        color: AppTheme.mutedFg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Footer
                  Text(
                    'СЛОВА ИЗ СЛОВА · РУССКИЙ ЯЗЫК',
                    style: AppTheme.condensedLabel,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _decorativeTiles() {
    const letters = ['С', 'Л', 'О', 'В', 'А'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(letters.length, (i) {
        final rotation = (i * 3 - 6) * 3.14159 / 180;
        return Transform.rotate(
          angle: rotation,
          child: Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: AppTheme.tileBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.border.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                  color: AppTheme.foreground.withValues(alpha: 0.15),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              letters[i],
              style: AppTheme.tileLabel,
            ),
          ),
        );
      })
          .animate(interval: 100.ms)
          .fadeIn(duration: 300.ms)
          .slideY(begin: -0.3, end: 0, duration: 300.ms),
    );
  }

  Widget _playButton({
    required BuildContext context,
    required LanguageMode mode,
    required String label,
    required String sublabel,
    required String flag,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: () async {
          final settings = context.read<SettingsProvider>();
          final game = context.read<GameProvider>();
          await settings.setLanguageMode(mode);
          await game.startGame(mode);
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GameScreen()),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppTheme.primaryFg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.condensedBold.copyWith(
                    color: AppTheme.primaryFg,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  sublabel,
                  style: AppTheme.condensedLabel.copyWith(
                    color: AppTheme.primaryFg.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _HomeMain — shown on re-entry when language is already set
// ---------------------------------------------------------------------------

class _HomeMain extends StatelessWidget {
  final LanguageMode mode;

  const _HomeMain({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final isRussian = mode == LanguageMode.russian;
    final flag = isRussian ? '🇷🇺' : '🇺🇸';
    final langLabel = isRussian ? 'Русский' : 'English';
    final startLabel = isRussian ? 'Играть' : 'Play';

    return Scaffold(
      body: GridPaperBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Gear icon — top right
              Positioned(
                top: 0,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.settings, color: AppTheme.foreground),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                ),
              ),

              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),

                      // Title
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Слова ',
                              style: AppTheme.displayLarge.copyWith(
                                color: AppTheme.primary,
                              ),
                            ),
                            TextSpan(
                              text: 'из Слова',
                              style: AppTheme.displayLarge,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Words from a Word',
                        style: AppTheme.condensedLabel.copyWith(
                          fontSize: 12,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Decorative tiles
                      _decorativeTiles(),
                      const SizedBox(height: 40),

                      // Language badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(flag, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(
                            langLabel,
                            style: AppTheme.condensedBold.copyWith(
                              color: AppTheme.mutedFg,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Start game CTA
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton(
                          onPressed: () async {
                            final game = context.read<GameProvider>();
                            await game.startGame(mode);
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const GameScreen(),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: AppTheme.primaryFg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                          child: Text(
                            startLabel,
                            style: AppTheme.condensedBold.copyWith(
                              color: AppTheme.primaryFg,
                              fontSize: 20,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Rules button
                      TextButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => RulesModal(languageMode: mode),
                          );
                        },
                        child: Text(
                          isRussian ? 'Правила' : 'Rules',
                          style: AppTheme.condensedBold.copyWith(
                            color: AppTheme.mutedFg,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Footer
                      Text(
                        'СЛОВА ИЗ СЛОВА · РУССКИЙ ЯЗЫК',
                        style: AppTheme.condensedLabel,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _decorativeTiles() {
    const letters = ['С', 'Л', 'О', 'В', 'А'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(letters.length, (i) {
        final rotation = (i * 3 - 6) * 3.14159 / 180;
        return Transform.rotate(
          angle: rotation,
          child: Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: AppTheme.tileBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.border.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                  color: AppTheme.foreground.withValues(alpha: 0.15),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              letters[i],
              style: AppTheme.tileLabel,
            ),
          ),
        );
      })
          .animate(interval: 100.ms)
          .fadeIn(duration: 300.ms)
          .slideY(begin: -0.3, end: 0, duration: 300.ms),
    );
  }
}

// lib/screens/trophies_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/achievements.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/rewards_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/trophy_badge.dart';

class TrophiesScreen extends StatelessWidget {
  const TrophiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<SettingsProvider>().languageMode ?? LanguageMode.english;
    final isRu = mode == LanguageMode.russian;
    final rewards = context.watch<RewardsProvider>();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(isRu ? StringsRu.trophiesTitle : StringsEn.trophiesTitle)),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 16, crossAxisSpacing: 8,
          childAspectRatio: 0.75,
        ),
        itemCount: kAchievements.length,
        itemBuilder: (ctx, i) {
          final a = kAchievements[i];
          final unlocked = rewards.achievementsUnlocked.contains(a.id);
          return TrophyBadge(
            title: a.title(mode),
            unlocked: unlocked,
            onTap: () => showModalBottomSheet(
              context: ctx,
              builder: (_) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(a.title(mode), style: AppTheme.displayMedium),
                  const SizedBox(height: 12),
                  Text(a.description(mode), style: AppTheme.condensedBold),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

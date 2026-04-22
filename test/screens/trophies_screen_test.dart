import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/data/achievements.dart';
import 'package:slova_iz_slova/models/language_mode.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';
import 'package:slova_iz_slova/providers/settings_provider.dart';
import 'package:slova_iz_slova/screens/trophies_screen.dart';
import 'package:slova_iz_slova/widgets/trophy_badge.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('TrophiesScreen renders correct unlock/lock states', (tester) async {
    final rewards = RewardsProvider();
    await rewards.load();

    // Seed 3 achievements as unlocked.
    rewards.achievementsUnlocked.addAll({'first_word', 'first_bonus', 'first_level'});
    rewards.notifyListeners();

    final settings = SettingsProvider();
    await settings.setLanguageMode(LanguageMode.english);

    // Use a tall surface so GridView renders all 14 items without lazy truncation.
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<RewardsProvider>.value(value: rewards),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ],
        child: const MaterialApp(
          home: TrophiesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // All 14 TrophyBadge widgets should be rendered.
    expect(find.byType(TrophyBadge), findsNWidgets(kAchievements.length));

    // 3 unlocked → trophy icon; 11 locked → lock icon.
    expect(find.byIcon(Icons.emoji_events), findsNWidgets(3));
    expect(find.byIcon(Icons.lock), findsNWidgets(kAchievements.length - 3));
  });
}

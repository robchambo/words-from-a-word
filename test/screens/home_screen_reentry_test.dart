import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/models/language_mode.dart';
import 'package:slova_iz_slova/providers/game_provider.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';
import 'package:slova_iz_slova/services/ad_gateway.dart';
import 'package:slova_iz_slova/providers/settings_provider.dart';
import 'package:slova_iz_slova/screens/home_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(SettingsProvider s) {
    final rewards = RewardsProvider();
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: s),
          ChangeNotifierProvider<RewardsProvider>.value(value: rewards),
          ChangeNotifierProvider<GameProvider>(
            create: (_) => GameProvider(rewards: rewards, adGateway: NoopAdGateway()),
          ),
        ],
        child: const HomeScreen(),
      ),
    );
  }

  testWidgets('shows language picker when languageMode is null', (tester) async {
    final s = SettingsProvider();
    await s.load();
    expect(s.languageMode, isNull);

    await tester.pumpWidget(wrap(s));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('language-picker')), findsOneWidget);
  });

  testWidgets('skips language picker when languageMode set', (tester) async {
    SharedPreferences.setMockInitialValues({
      'language_mode': 'russian',
    });
    final s = SettingsProvider();
    await s.load();
    expect(s.languageMode, LanguageMode.russian);

    await tester.pumpWidget(wrap(s));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('language-picker')), findsNothing);
    expect(find.byKey(const ValueKey('home-main')), findsOneWidget);
  });
}

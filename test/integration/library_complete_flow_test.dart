import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/engine/level_loader.dart';
import 'package:slova_iz_slova/models/language_mode.dart';
import 'package:slova_iz_slova/providers/game_provider.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';
import 'package:slova_iz_slova/services/ad_gateway.dart';
import 'package:slova_iz_slova/providers/settings_provider.dart';
import 'package:slova_iz_slova/screens/game_screen.dart';
import 'package:slova_iz_slova/screens/library_complete_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LevelLoader.preload();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'game screen routes to LibraryCompleteScreen when nextLevel passes end of library',
      (tester) async {
    // Set a large surface so widgets can lay out without overflow errors.
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({});
    final rewards = RewardsProvider();
    await rewards.load();

    final game = GameProvider(rewards: rewards, adGateway: NoopAdGateway());
    // Start at the last English level (20).
    await game.startGame(LanguageMode.english, levelNumber: 20);

    // Advance past the end of the library — this sets libraryComplete = true.
    game.nextLevel(LanguageMode.english);
    expect(game.state.libraryComplete, isTrue,
        reason: 'nextLevel past last level must set libraryComplete');

    final settings = SettingsProvider();
    await settings.setLanguageMode(LanguageMode.english);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<RewardsProvider>.value(value: rewards),
          ChangeNotifierProvider<GameProvider>.value(value: game),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ],
        child: const MaterialApp(home: GameScreen()),
      ),
    );

    // Allow postFrameCallback + navigation to complete.
    await tester.pumpAndSettle();

    expect(find.byType(LibraryCompleteScreen), findsOneWidget);
  });
}

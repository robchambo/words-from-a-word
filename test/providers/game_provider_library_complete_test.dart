import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/engine/level_loader.dart';
import 'package:slova_iz_slova/models/language_mode.dart';
import 'package:slova_iz_slova/providers/game_provider.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized();
    await LevelLoader.preload();
  });

  group('GameProvider end-of-library', () {
    test(
        'nextLevel sets libraryComplete when called beyond last English level',
        () async {
      // English library has 20 levels. Start on level 20, then call nextLevel
      // to simulate completing the last level and advancing past the end.
      final rewards = RewardsProvider();
      await rewards.load();
      final game = GameProvider(rewards: rewards);
      await game.startGame(LanguageMode.english, levelNumber: 20);

      expect(game.state.libraryComplete, isFalse);

      game.nextLevel(LanguageMode.english);

      expect(game.state.libraryComplete, isTrue);
    });

    test('isReplayMode is stored from startGame parameter', () async {
      final rewards = RewardsProvider();
      await rewards.load();
      final game = GameProvider(rewards: rewards);

      await game.startGame(LanguageMode.english, levelNumber: 1, isReplay: true);
      expect(game.state.isReplayMode, isTrue);

      await game.startGame(LanguageMode.english, levelNumber: 1);
      expect(game.state.isReplayMode, isFalse);
    });

    test(
        'nextLevel within bounds does not set libraryComplete',
        () async {
      final rewards = RewardsProvider();
      await rewards.load();
      final game = GameProvider(rewards: rewards);
      await game.startGame(LanguageMode.english, levelNumber: 1);

      game.nextLevel(LanguageMode.english);

      expect(game.state.libraryComplete, isFalse);
      expect(game.state.level.levelNumber, greaterThan(0));
    });
  });
}

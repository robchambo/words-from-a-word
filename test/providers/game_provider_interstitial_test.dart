import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/engine/level_loader.dart';
import 'package:slova_iz_slova/models/language_mode.dart';
import 'package:slova_iz_slova/providers/game_provider.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';
import 'package:slova_iz_slova/services/ad_gateway.dart';

class _MockAdGateway extends Mock implements AdGateway {}

Future<void> _submitWord(GameProvider game, String word) async {
  final lower = word.toLowerCase();
  for (final ch in lower.split('')) {
    final tile = game.state.level.sourceLetters.firstWhere(
      (t) => !t.isSelected && !t.isUsed && t.letter.toLowerCase() == ch,
      orElse: () => throw StateError('no tile for letter $ch'),
    );
    game.selectTile(tile.id);
  }
  game.submitWord();
}

Future<void> _completeLevel(GameProvider game) async {
  final required = game.state.level.targetWords
      .where((tw) => !tw.isBonus)
      .map((tw) => tw.word)
      .toList();
  for (final w in required) {
    await _submitWord(game, w);
  }
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LevelLoader.preload();
  });

  test('non-premium: interstitial attempted on bankAndAdvance', () async {
    final rewards = RewardsProvider();
    await rewards.load();
    final ad = _MockAdGateway();
    when(() => ad.showInterstitial()).thenAnswer((_) async => true);

    final gp = GameProvider(rewards: rewards, adGateway: ad);
    await gp.startGame(LanguageMode.russian, levelNumber: 1);

    await _completeLevel(gp);
    expect(gp.state.isLevelComplete, isTrue,
        reason: 'test setup: level must be complete before banking');

    await gp.bankAndAdvance(LanguageMode.russian);
    verify(() => ad.showInterstitial()).called(1);
  });

  test('premium: interstitial skipped on bankAndAdvance', () async {
    SharedPreferences.setMockInitialValues({'rewards.premium': true});
    final rewards = RewardsProvider();
    await rewards.load();
    expect(rewards.premium, isTrue, reason: 'test setup');

    final ad = _MockAdGateway();
    final gp = GameProvider(rewards: rewards, adGateway: ad);
    await gp.startGame(LanguageMode.russian, levelNumber: 1);

    await _completeLevel(gp);
    expect(gp.state.isLevelComplete, isTrue);

    await gp.bankAndAdvance(LanguageMode.russian);
    verifyNever(() => ad.showInterstitial());
  });
}

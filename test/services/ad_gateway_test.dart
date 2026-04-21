import 'package:flutter_test/flutter_test.dart';
import 'package:slova_iz_slova/services/ad_gateway.dart';

void main() {
  group('NoopAdGateway', () {
    late NoopAdGateway gateway;

    setUp(() {
      gateway = NoopAdGateway();
    });

    test('initialize is a no-op', () async {
      await gateway.initialize();
    });

    test('showInterstitial returns false', () async {
      final shown = await gateway.showInterstitial();
      expect(shown, isFalse);
    });

    test('showRewarded calls onReward and returns true', () async {
      var rewarded = false;
      final shown = await gateway.showRewarded(onReward: () => rewarded = true);
      expect(shown, isTrue);
      expect(rewarded, isTrue);
    });
  });

  test('HintSource enum values', () {
    expect(HintSource.values, [
      HintSource.freeSlot,
      HintSource.purchased,
      HintSource.rewardedAd,
    ]);
  });
}

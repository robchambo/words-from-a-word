import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';

void main() {
  test('schema v1 upgrades to v2 with empty bankedBonusWords', () async {
    SharedPreferences.setMockInitialValues({
      'rewards.schemaVersion': 1,
      'rewards.freeHintSlot': 1,
    });
    final r = RewardsProvider();
    await r.load();
    expect(r.schemaVersion, 2);
    expect(r.freeHintSlot, 1);
    expect(r.bankedBonusWords, isNotNull);
    final sp = await SharedPreferences.getInstance();
    expect(sp.getInt('rewards.schemaVersion'), 2);
  });

  test('fresh install starts at v2', () async {
    SharedPreferences.setMockInitialValues({});
    final r = RewardsProvider();
    await r.load();
    expect(r.schemaVersion, 2);
  });
}

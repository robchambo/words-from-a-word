import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';
import 'package:slova_iz_slova/models/language_mode.dart';

void main() {
  DateTime now = DateTime(2026, 4, 16);
  DateTime clock() => now;

  setUp(() async {
    now = DateTime(2026, 4, 16);
    SharedPreferences.setMockInitialValues({});
  });

  test('first completion: streak = 1', () async {
    final p = RewardsProvider(clock: clock);
    await p.load();
    p.onLevelComplete(
        mode: LanguageMode.english, levelId: 1, pendingScore: 100, isReplay: false);
    expect(p.streakCount, 1);
  });

  test('same-day second completion does not double streak', () async {
    final p = RewardsProvider(clock: clock);
    await p.load();
    p.onLevelComplete(
        mode: LanguageMode.english, levelId: 1, pendingScore: 100, isReplay: false);
    p.onLevelComplete(
        mode: LanguageMode.english, levelId: 2, pendingScore: 100, isReplay: false);
    expect(p.streakCount, 1);
  });

  test('next-day completion increments streak', () async {
    final p = RewardsProvider(clock: clock);
    await p.load();
    p.onLevelComplete(
        mode: LanguageMode.english, levelId: 1, pendingScore: 100, isReplay: false);
    now = DateTime(2026, 4, 17);
    p.onLevelComplete(
        mode: LanguageMode.english, levelId: 2, pendingScore: 100, isReplay: false);
    expect(p.streakCount, 2);
  });

  test('2-day gap resets streak to 1', () async {
    final p = RewardsProvider(clock: clock);
    await p.load();
    p.onLevelComplete(
        mode: LanguageMode.english, levelId: 1, pendingScore: 100, isReplay: false);
    now = DateTime(2026, 4, 18);
    p.onLevelComplete(
        mode: LanguageMode.english, levelId: 2, pendingScore: 100, isReplay: false);
    expect(p.streakCount, 1);
  });

  test('replay does not update streak', () async {
    final p = RewardsProvider(clock: clock);
    await p.load();
    p.onLevelComplete(
        mode: LanguageMode.english, levelId: 1, pendingScore: 100, isReplay: false);
    now = DateTime(2026, 4, 17);
    p.onLevelComplete(
        mode: LanguageMode.english, levelId: 1, pendingScore: 100, isReplay: true);
    expect(p.streakCount, 1);
  });
}

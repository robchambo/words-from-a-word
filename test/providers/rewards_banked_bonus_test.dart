import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/models/language_mode.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('bankBonusWords stores and dedupes', () async {
    final r = RewardsProvider();
    await r.load();
    final n1 = r.bankBonusWords(
        mode: LanguageMode.english, levelId: 3, words: ['cat', 'dog']);
    expect(n1, 2);
    final n2 = r.bankBonusWords(
        mode: LanguageMode.english, levelId: 3, words: ['cat', 'bat']);
    expect(n2, 1);
    expect(r.bankedBonusWords[LanguageMode.english]![3], {'cat', 'dog', 'bat'});
  });

  test('bankedBonusLevel returns attribution across levels', () async {
    final r = RewardsProvider();
    await r.load();
    r.bankBonusWords(
        mode: LanguageMode.english, levelId: 5, words: ['owl']);
    r.bankBonusWords(
        mode: LanguageMode.english, levelId: 7, words: ['fox']);
    expect(r.bankedBonusLevel(mode: LanguageMode.english, word: 'owl'), 5);
    expect(r.bankedBonusLevel(mode: LanguageMode.english, word: 'fox'), 7);
    expect(r.bankedBonusLevel(mode: LanguageMode.english, word: 'dog'), isNull);
    expect(r.bankedBonusLevel(mode: LanguageMode.english, word: 'OWL'), 5);
  });

  test('persists across load/reload', () async {
    final r = RewardsProvider();
    await r.load();
    r.bankBonusWords(
        mode: LanguageMode.russian, levelId: 2, words: ['кот']);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final r2 = RewardsProvider();
    await r2.load();
    expect(r2.bankedBonusWords[LanguageMode.russian]![2], {'кот'});
  });
}

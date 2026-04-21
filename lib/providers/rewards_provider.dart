import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/language_mode.dart';
// ignore: unused_import
import '../services/ad_gateway.dart'; // for HintSource

/// Owns all persisted v1.1 player state except language. See
/// `docs/V1_1_CONTRACTS.md` for authoritative field list and persistence keys.
class RewardsProvider extends ChangeNotifier {
  RewardsProvider({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  // ignore: unused_field
  final DateTime Function() _clock;

  static const int _currentSchemaVersion = 1;
  static const int _freeHintSlotCapFree = 1;
  static const int _freeHintSlotCapPremium = 3;
  // ignore: unused_field
  static const int _bonusRefillThreshold = 10;

  // --- Persisted fields --------------------------------------------------
  int schemaVersion = _currentSchemaVersion;
  int freeHintSlot = 0;
  int bonusWordCounter = 0;
  DateTime? lastDailyClaimedOn;
  int purchasedHintCount = 0;
  bool premium = false;
  int streakCount = 0;
  DateTime? streakLastPlayedOn;
  Set<String> achievementsUnlocked = <String>{};
  Map<LanguageMode, int> currentLevel = {
    LanguageMode.russian: 1,
    LanguageMode.english: 1,
  };
  Map<LanguageMode, int> highestCompletedLevel = {
    LanguageMode.russian: 0,
    LanguageMode.english: 0,
  };
  Map<LanguageMode, Map<int, int>> levelBestScore = {
    LanguageMode.russian: <int, int>{},
    LanguageMode.english: <int, int>{},
  };
  Map<LanguageMode, int> lifetimeScore = {
    LanguageMode.russian: 0,
    LanguageMode.english: 0,
  };

  // --- Derived ----------------------------------------------------------
  // ignore: unused_element
  int get _slotCap => premium ? _freeHintSlotCapPremium : _freeHintSlotCapFree;
  bool get canUseHint => freeHintSlot > 0 || purchasedHintCount > 0;

  // --- Keys -------------------------------------------------------------
  static const _kSchemaVersion = 'rewards.schemaVersion';
  static const _kFreeHintSlot = 'rewards.freeHintSlot';
  static const _kBonusCounter = 'rewards.bonusWordCounter';
  static const _kLastDailyClaimedOn = 'rewards.lastDailyClaimedOn';
  static const _kPurchasedHintCount = 'rewards.purchasedHintCount';
  static const _kPremium = 'rewards.premium';
  static const _kStreakCount = 'rewards.streakCount';
  static const _kStreakLastPlayedOn = 'rewards.streakLastPlayedOn';
  static const _kAchievementsUnlocked = 'rewards.achievementsUnlocked';

  String _currentLevelKey(LanguageMode m) => 'rewards.currentLevel.${_modeKey(m)}';
  String _highestKey(LanguageMode m) => 'rewards.highestCompletedLevel.${_modeKey(m)}';
  String _bestScoreKey(LanguageMode m) => 'rewards.levelBestScore.${_modeKey(m)}';
  String _lifetimeKey(LanguageMode m) => 'rewards.lifetimeScore.${_modeKey(m)}';
  String _modeKey(LanguageMode m) => m == LanguageMode.russian ? 'ru' : 'en';

  // --- Load / Save ------------------------------------------------------
  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();

    schemaVersion = sp.getInt(_kSchemaVersion) ?? _currentSchemaVersion;
    freeHintSlot = sp.getInt(_kFreeHintSlot) ?? 0;
    bonusWordCounter = sp.getInt(_kBonusCounter) ?? 0;
    lastDailyClaimedOn = _parseDate(sp.getString(_kLastDailyClaimedOn));
    purchasedHintCount = sp.getInt(_kPurchasedHintCount) ?? 0;
    premium = sp.getBool(_kPremium) ?? false;
    streakCount = sp.getInt(_kStreakCount) ?? 0;
    streakLastPlayedOn = _parseDate(sp.getString(_kStreakLastPlayedOn));
    achievementsUnlocked = _parseStringSet(sp.getString(_kAchievementsUnlocked));

    for (final m in LanguageMode.values) {
      currentLevel[m] = sp.getInt(_currentLevelKey(m)) ?? 1;
      highestCompletedLevel[m] = sp.getInt(_highestKey(m)) ?? 0;
      levelBestScore[m] = _parseScoreMap(sp.getString(_bestScoreKey(m)));
      lifetimeScore[m] = sp.getInt(_lifetimeKey(m)) ?? 0;
    }

    notifyListeners();
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();

    await sp.setInt(_kSchemaVersion, schemaVersion);
    await sp.setInt(_kFreeHintSlot, freeHintSlot);
    await sp.setInt(_kBonusCounter, bonusWordCounter);
    await _writeDate(sp, _kLastDailyClaimedOn, lastDailyClaimedOn);
    await sp.setInt(_kPurchasedHintCount, purchasedHintCount);
    await sp.setBool(_kPremium, premium);
    await sp.setInt(_kStreakCount, streakCount);
    await _writeDate(sp, _kStreakLastPlayedOn, streakLastPlayedOn);
    await sp.setString(
      _kAchievementsUnlocked,
      jsonEncode(achievementsUnlocked.toList()),
    );

    for (final m in LanguageMode.values) {
      await sp.setInt(_currentLevelKey(m), currentLevel[m] ?? 1);
      await sp.setInt(_highestKey(m), highestCompletedLevel[m] ?? 0);
      await sp.setString(
        _bestScoreKey(m),
        jsonEncode(
          levelBestScore[m]!.map((k, v) => MapEntry(k.toString(), v)),
        ),
      );
      await sp.setInt(_lifetimeKey(m), lifetimeScore[m] ?? 0);
    }
  }

  // --- Parsers / writers ------------------------------------------------
  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDate(SharedPreferences sp, String key, DateTime? d) async {
    if (d == null) {
      await sp.remove(key);
    } else {
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      await sp.setString(key, '$y-$m-$dd');
    }
  }

  Set<String> _parseStringSet(String? s) {
    if (s == null || s.isEmpty) return <String>{};
    try {
      final list = jsonDecode(s) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Map<int, int> _parseScoreMap(String? s) {
    if (s == null || s.isEmpty) return <int, int>{};
    try {
      final raw = jsonDecode(s) as Map<String, dynamic>;
      return raw.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
    } catch (_) {
      return <int, int>{};
    }
  }
}

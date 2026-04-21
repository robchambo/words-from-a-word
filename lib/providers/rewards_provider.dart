import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/language_mode.dart';
import '../services/ad_gateway.dart';

/// Owns all persisted v1.1 player state except language. See
/// `docs/V1_1_CONTRACTS.md` for authoritative field list and persistence keys.
class RewardsProvider extends ChangeNotifier {
  RewardsProvider({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const int _currentSchemaVersion = 1;
  static const int _freeHintSlotCapFree = 1;
  static const int _freeHintSlotCapPremium = 3;
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

  /// Tick incremented every time the bonus-word accumulator converts into a
  /// new free hint. UI observes this with a `ValueListenableBuilder` or
  /// `addListener` to fire the FreeHintEarnedOverlay. We use a ValueNotifier
  /// instead of `notifyListeners()` so subscribers that only care about the
  /// celebratory event don't rebuild on every save.
  final ValueNotifier<int> freeHintEarnedTicks = ValueNotifier<int>(0);

  // --- Derived ----------------------------------------------------------
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

  // --- Business logic ---------------------------------------------------
  /// Grants a free hint if `lastDailyClaimedOn` is before today (local) AND
  /// `freeHintSlot < cap`. Stamp the date either way so we don't recheck
  /// repeatedly within the same day. Call on app resume and level start.
  void maybeRefillDailyHint() {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);

    final already = lastDailyClaimedOn;
    if (already != null &&
        already.year == today.year &&
        already.month == today.month &&
        already.day == today.day) {
      return;
    }

    final cap = _slotCap;
    if (freeHintSlot < cap) {
      freeHintSlot += 1;
    }
    lastDailyClaimedOn = today;
    notifyListeners();
    // fire-and-forget persist
    save();
  }

  /// Consume one hint from the waterfall: free slot first, then purchased
  /// pool. Returns the source used. Returns null if the caller should fall
  /// back to a rewarded ad (handled upstream).
  HintSource? consumeHint() {
    if (freeHintSlot > 0) {
      freeHintSlot -= 1;
      notifyListeners();
      save();
      return HintSource.freeSlot;
    }
    if (purchasedHintCount > 0) {
      purchasedHintCount -= 1;
      notifyListeners();
      save();
      return HintSource.purchased;
    }
    return null;
  }

  /// Credit n hints into the purchased pool. Used by rewarded-ad reward and
  /// by the hint-pack IAP (which calls with n=5).
  void addPurchasedHints(int n) {
    if (n <= 0) return;
    purchasedHintCount += n;
    notifyListeners();
    save();
  }

  /// Record a bonus-word find. Bumps the counter; on reaching the refill
  /// threshold, decrements by 10 and grants a free hint (unless slot full,
  /// in which case the counter freezes at 10 until the slot drains).
  void incrementBonusCounter() {
    if (bonusWordCounter >= _bonusRefillThreshold) {
      // frozen — nothing to do
      return;
    }
    bonusWordCounter += 1;
    if (bonusWordCounter >= _bonusRefillThreshold) {
      if (freeHintSlot < _slotCap) {
        bonusWordCounter = 0;
        freeHintSlot += 1;
        freeHintEarnedTicks.value = freeHintEarnedTicks.value + 1;
      }
      // else keep at 10, slot is full; caller owns popup UX
    }
    notifyListeners();
    save();
  }

  @override
  void dispose() {
    freeHintEarnedTicks.dispose();
    super.dispose();
  }

  /// Set premium flag. Does not itself refill — call
  /// `maybeRefillDailyHint()` or let the next level-start call do it.
  void markPremium() {
    if (premium) return;
    premium = true;
    notifyListeners();
    save();
  }

  /// Called by GameProvider when a non-replay level completes. Phase 3 will
  /// extend this with streak logic + `isReplay` guarding; for Phase 1 we only
  /// persist best score, lifetime score, and advance the current level
  /// pointer.
  void onLevelComplete({
    required LanguageMode mode,
    required int levelId,
    required int pendingScore,
  }) {
    final best = levelBestScore[mode]![levelId] ?? 0;
    if (pendingScore > best) {
      levelBestScore[mode]![levelId] = pendingScore;
    }
    lifetimeScore[mode] = (lifetimeScore[mode] ?? 0) + pendingScore;

    final prevHigh = highestCompletedLevel[mode] ?? 0;
    if (levelId > prevHigh) {
      highestCompletedLevel[mode] = levelId;
    }
    final prevCurrent = currentLevel[mode] ?? 1;
    if (levelId + 1 > prevCurrent) {
      currentLevel[mode] = levelId + 1;
    }

    notifyListeners();
    save();
  }

  /// Record an achievement unlock. Idempotent. Phase 3 AchievementEngine
  /// wraps this with event hooks and analytics.
  void unlockAchievement(String id) {
    if (achievementsUnlocked.add(id)) {
      notifyListeners();
      save();
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

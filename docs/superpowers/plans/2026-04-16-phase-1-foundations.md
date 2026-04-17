# Phase 1 — Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the three architectural pillars (`RewardsProvider`, `AdGateway`, `AudioService`), scaffold the Settings screen, and add a re-entry flow so the home screen skips the language picker when a language is already set. Nothing user-visible changes gameplay — this is purely foundations for Phases 2-6.

**Architecture:** `RewardsProvider` is a new `ChangeNotifier` registered above `GameProvider` in the provider tree and persisted to `shared_preferences` with a `schemaVersion` key. `AdGateway` is an abstract class with a `NoopAdGateway` default registered as a `Provider<AdGateway>`. `AudioService` is a singleton (no provider) with no-op method bodies — Phase 4 swaps in the real `audioplayers` impl. Names, fields, and persistence keys come verbatim from `docs/V1_1_CONTRACTS.md` — do not drift.

**Tech Stack:** Dart 3.11, Flutter, `provider ^6.1.2`, `shared_preferences ^2.2.3` (existing), `flutter_test`, `mocktail ^1.0.3` (new, dev only).

---

## File Structure

- **Create**
  - `lib/providers/rewards_provider.dart` — the new provider. Owns all persisted v1.1 state except language.
  - `lib/services/ad_gateway.dart` — `AdGateway` abstract class + `HintSource` enum (re-exported) + `NoopAdGateway` impl.
  - `lib/services/audio_service.dart` — singleton skeleton. All `play*` methods no-op. `setMuted` updates internal flag.
  - `lib/screens/settings_screen.dart` — scaffold with 6 stub rows (language, rules, mute, remove ads, restore, privacy).
  - `lib/widgets/settings_row.dart` — small list-row widget used by settings screen (label + trailing control + tap handler).
  - `test/providers/rewards_provider_test.dart`
  - `test/services/ad_gateway_test.dart`
  - `test/services/audio_service_test.dart`
  - `test/screens/settings_screen_test.dart`

- **Modify**
  - `pubspec.yaml` — add `mocktail` under `dev_dependencies`.
  - `lib/main.dart` — load `SettingsProvider` + `RewardsProvider` before `runApp`; register `AdGateway` in provider tree.
  - `lib/app.dart` — add `SettingsScreen` route; pass re-entry decision to home screen.
  - `lib/screens/home_screen.dart` — skip language picker if `SettingsProvider.languageMode != null`; add gear icon → settings screen.
  - `lib/providers/settings_provider.dart` — add `muted` field (persisted, default false) in preparation for Phase 4; no UI change here.
  - `lib/l10n/strings_ru.dart`, `lib/l10n/strings_en.dart` — add the settings-screen keys listed in `V1_1_CONTRACTS.md`.

---

## Task 1: Add `mocktail` dev dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dev dependency**

In `pubspec.yaml`, under `dev_dependencies:`, add:

```yaml
  mocktail: ^1.0.3
```

Place alphabetically.

- [ ] **Step 2: Run pub get**

Run: `flutter pub get`
Expected: "Got dependencies!"

- [ ] **Step 3: Verify analyze still clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add mocktail dev dependency for Phase 1 tests"
```

---

## Task 2: Create `HintSource` enum and `AdGateway` abstract

**Files:**
- Create: `lib/services/ad_gateway.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/ad_gateway_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/ad_gateway_test.dart`
Expected: FAIL — `ad_gateway.dart` not found.

- [ ] **Step 3: Write minimal implementation**

Create `lib/services/ad_gateway.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Where a hint came from when `RewardsProvider.consumeHint()` succeeded.
enum HintSource { freeSlot, purchased, rewardedAd }

/// Abstraction over ad network SDKs. Swapped from [NoopAdGateway] to
/// MobileAdsGateway in Phase 5. Consumers read this via
/// `context.read<AdGateway>()`.
abstract class AdGateway {
  Future<void> initialize();
  Future<void> loadInterstitial();

  /// Returns true if an interstitial was shown.
  Future<bool> showInterstitial();

  Future<void> loadRewarded();

  /// Calls [onReward] if the user watched to completion. Returns true if the
  /// ad played at all (even if the user abandoned partway).
  Future<bool> showRewarded({required VoidCallback onReward});
}

/// Default, development-safe implementation. Logs intent, reward-grants
/// immediately, never shows anything real.
class NoopAdGateway implements AdGateway {
  @override
  Future<void> initialize() async {
    debugPrint('[NoopAdGateway] initialize');
  }

  @override
  Future<void> loadInterstitial() async {
    debugPrint('[NoopAdGateway] loadInterstitial');
  }

  @override
  Future<bool> showInterstitial() async {
    debugPrint('[NoopAdGateway] showInterstitial -> false');
    return false;
  }

  @override
  Future<void> loadRewarded() async {
    debugPrint('[NoopAdGateway] loadRewarded');
  }

  @override
  Future<bool> showRewarded({required VoidCallback onReward}) async {
    debugPrint('[NoopAdGateway] showRewarded -> grant immediately');
    onReward();
    return true;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/ad_gateway_test.dart`
Expected: PASS — 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/ad_gateway.dart test/services/ad_gateway_test.dart
git commit -m "feat: add AdGateway abstract + NoopAdGateway default impl"
```

---

## Task 3: Create `AudioService` singleton skeleton

**Files:**
- Create: `lib/services/audio_service.dart`
- Create: `test/services/audio_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/audio_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:slova_iz_slova/services/audio_service.dart';

void main() {
  group('AudioService', () {
    final service = AudioService.instance;

    test('is a singleton', () {
      expect(AudioService.instance, same(service));
    });

    test('defaults to unmuted', () {
      // reset for test isolation
      service.setMuted(false);
      expect(service.isMuted, isFalse);
    });

    test('setMuted updates isMuted', () {
      service.setMuted(true);
      expect(service.isMuted, isTrue);
      service.setMuted(false);
      expect(service.isMuted, isFalse);
    });

    test('play* methods complete without throwing (no-op skeleton)', () async {
      await service.initialize();
      await service.playTap();
      await service.playSuccess();
      await service.playError();
      await service.playLevelComplete();
      await service.playHintReveal();
      await service.playFreeHintEarned();
      await service.playBonusRefill();
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/audio_service_test.dart`
Expected: FAIL — `audio_service.dart` not found.

- [ ] **Step 3: Write minimal implementation**

Create `lib/services/audio_service.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Fire-and-forget sound-effects singleton. Phase 1 skeleton: all play*
/// methods are no-ops so the wiring sites in later phases can be added
/// without waiting on audio assets. Phase 4 swaps the bodies for real
/// `audioplayers` calls.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  bool _muted = false;
  bool get isMuted => _muted;

  /// Preload clips. No-op in Phase 1.
  Future<void> initialize() async {
    debugPrint('[AudioService] initialize (skeleton)');
  }

  void setMuted(bool muted) {
    _muted = muted;
    debugPrint('[AudioService] setMuted($muted)');
  }

  Future<void> playTap() async {}
  Future<void> playSuccess() async {}
  Future<void> playError() async {}
  Future<void> playLevelComplete() async {}
  Future<void> playHintReveal() async {}
  Future<void> playFreeHintEarned() async {}
  Future<void> playBonusRefill() async {}
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/audio_service_test.dart`
Expected: PASS — 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/audio_service.dart test/services/audio_service_test.dart
git commit -m "feat: add AudioService singleton skeleton"
```

---

## Task 4: Write failing tests for `RewardsProvider` load/save

**Files:**
- Create: `test/providers/rewards_provider_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/providers/rewards_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/models/language_mode.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RewardsProvider initial state', () {
    test('defaults are correct on cold load', () async {
      final provider = RewardsProvider();
      await provider.load();

      expect(provider.schemaVersion, 1);
      expect(provider.freeHintSlot, 0);
      expect(provider.bonusWordCounter, 0);
      expect(provider.lastDailyClaimedOn, isNull);
      expect(provider.purchasedHintCount, 0);
      expect(provider.premium, isFalse);
      expect(provider.streakCount, 0);
      expect(provider.streakLastPlayedOn, isNull);
      expect(provider.achievementsUnlocked, isEmpty);
      expect(provider.currentLevel[LanguageMode.russian], 1);
      expect(provider.currentLevel[LanguageMode.english], 1);
      expect(provider.highestCompletedLevel[LanguageMode.russian], 0);
      expect(provider.highestCompletedLevel[LanguageMode.english], 0);
      expect(provider.levelBestScore[LanguageMode.russian], isEmpty);
      expect(provider.levelBestScore[LanguageMode.english], isEmpty);
      expect(provider.lifetimeScore[LanguageMode.russian], 0);
      expect(provider.lifetimeScore[LanguageMode.english], 0);
    });
  });

  group('RewardsProvider persistence round-trip', () {
    test('saves and reloads all fields', () async {
      SharedPreferences.setMockInitialValues({
        'rewards.schemaVersion': 1,
        'rewards.freeHintSlot': 1,
        'rewards.bonusWordCounter': 7,
        'rewards.lastDailyClaimedOn': '2026-04-15',
        'rewards.purchasedHintCount': 3,
        'rewards.premium': true,
        'rewards.streakCount': 4,
        'rewards.streakLastPlayedOn': '2026-04-15',
        'rewards.achievementsUnlocked': '["first_word","first_level"]',
        'rewards.currentLevel.ru': 12,
        'rewards.currentLevel.en': 8,
        'rewards.highestCompletedLevel.ru': 11,
        'rewards.highestCompletedLevel.en': 7,
        'rewards.levelBestScore.ru': '{"1":120,"2":90}',
        'rewards.levelBestScore.en': '{"1":80}',
        'rewards.lifetimeScore.ru': 1500,
        'rewards.lifetimeScore.en': 800,
      });

      final provider = RewardsProvider();
      await provider.load();

      expect(provider.freeHintSlot, 1);
      expect(provider.bonusWordCounter, 7);
      expect(provider.lastDailyClaimedOn, DateTime(2026, 4, 15));
      expect(provider.purchasedHintCount, 3);
      expect(provider.premium, isTrue);
      expect(provider.streakCount, 4);
      expect(provider.streakLastPlayedOn, DateTime(2026, 4, 15));
      expect(provider.achievementsUnlocked, {'first_word', 'first_level'});
      expect(provider.currentLevel[LanguageMode.russian], 12);
      expect(provider.currentLevel[LanguageMode.english], 8);
      expect(provider.highestCompletedLevel[LanguageMode.russian], 11);
      expect(provider.highestCompletedLevel[LanguageMode.english], 7);
      expect(provider.levelBestScore[LanguageMode.russian]![1], 120);
      expect(provider.levelBestScore[LanguageMode.russian]![2], 90);
      expect(provider.levelBestScore[LanguageMode.english]![1], 80);
      expect(provider.lifetimeScore[LanguageMode.russian], 1500);
      expect(provider.lifetimeScore[LanguageMode.english], 800);
    });
  });

  group('RewardsProvider migration from v1.0', () {
    test('bare SharedPreferences (only languageMode) produces defaults', () async {
      SharedPreferences.setMockInitialValues({
        'settings.languageMode': 'russian',
      });

      final provider = RewardsProvider();
      await provider.load();

      expect(provider.schemaVersion, 1);
      expect(provider.freeHintSlot, 0);
      expect(provider.currentLevel[LanguageMode.russian], 1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/rewards_provider_test.dart`
Expected: FAIL — `rewards_provider.dart` not found.

- [ ] **Step 3: Commit the failing test (red)**

```bash
git add test/providers/rewards_provider_test.dart
git commit -m "test: add RewardsProvider load/save tests (failing)"
```

---

## Task 5: Implement `RewardsProvider` fields, load, save

**Files:**
- Create: `lib/providers/rewards_provider.dart`

- [ ] **Step 1: Write the implementation**

Create `lib/providers/rewards_provider.dart`:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/language_mode.dart';
import '../services/ad_gateway.dart'; // for HintSource

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
```

- [ ] **Step 2: Run test**

Run: `flutter test test/providers/rewards_provider_test.dart`
Expected: PASS — 3 tests.

- [ ] **Step 3: Commit**

```bash
git add lib/providers/rewards_provider.dart
git commit -m "feat: implement RewardsProvider fields + load/save"
```

---

## Task 6: Implement `maybeRefillDailyHint`

**Files:**
- Modify: `lib/providers/rewards_provider.dart`
- Modify: `test/providers/rewards_provider_test.dart`

- [ ] **Step 1: Add failing tests**

Append to `test/providers/rewards_provider_test.dart`:

```dart
  group('maybeRefillDailyHint', () {
    test('fills slot when never claimed and cap not reached', () async {
      final fakeNow = DateTime(2026, 4, 16, 9, 30);
      final provider = RewardsProvider(clock: () => fakeNow);
      await provider.load();

      provider.maybeRefillDailyHint();

      expect(provider.freeHintSlot, 1);
      expect(provider.lastDailyClaimedOn, DateTime(2026, 4, 16));
    });

    test('does not double-fill on same day', () async {
      SharedPreferences.setMockInitialValues({
        'rewards.freeHintSlot': 1,
        'rewards.lastDailyClaimedOn': '2026-04-16',
      });
      final fakeNow = DateTime(2026, 4, 16, 22, 0);
      final provider = RewardsProvider(clock: () => fakeNow);
      await provider.load();

      provider.maybeRefillDailyHint();

      expect(provider.freeHintSlot, 1);
    });

    test('fills on next day', () async {
      SharedPreferences.setMockInitialValues({
        'rewards.freeHintSlot': 0,
        'rewards.lastDailyClaimedOn': '2026-04-15',
      });
      final fakeNow = DateTime(2026, 4, 16, 0, 5);
      final provider = RewardsProvider(clock: () => fakeNow);
      await provider.load();

      provider.maybeRefillDailyHint();

      expect(provider.freeHintSlot, 1);
      expect(provider.lastDailyClaimedOn, DateTime(2026, 4, 16));
    });

    test('respects free cap of 1', () async {
      SharedPreferences.setMockInitialValues({
        'rewards.freeHintSlot': 1,
        'rewards.lastDailyClaimedOn': '2026-04-15',
      });
      final fakeNow = DateTime(2026, 4, 16);
      final provider = RewardsProvider(clock: () => fakeNow);
      await provider.load();

      provider.maybeRefillDailyHint();

      expect(provider.freeHintSlot, 1, reason: 'cap=1 for non-premium');
      expect(provider.lastDailyClaimedOn, DateTime(2026, 4, 16),
          reason: 'date is still stamped to prevent re-check within the day');
    });

    test('premium cap is 3', () async {
      SharedPreferences.setMockInitialValues({
        'rewards.freeHintSlot': 2,
        'rewards.premium': true,
        'rewards.lastDailyClaimedOn': '2026-04-15',
      });
      final fakeNow = DateTime(2026, 4, 16);
      final provider = RewardsProvider(clock: () => fakeNow);
      await provider.load();

      provider.maybeRefillDailyHint();

      expect(provider.freeHintSlot, 3);
    });
  });
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/providers/rewards_provider_test.dart`
Expected: FAIL — `maybeRefillDailyHint` not defined.

- [ ] **Step 3: Implement**

Add to `RewardsProvider`:

```dart
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
```

- [ ] **Step 4: Run test**

Run: `flutter test test/providers/rewards_provider_test.dart`
Expected: PASS — 8 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/rewards_provider.dart test/providers/rewards_provider_test.dart
git commit -m "feat: add maybeRefillDailyHint with clock injection"
```

---

## Task 7: Implement `consumeHint` + `addPurchasedHints`

**Files:**
- Modify: `lib/providers/rewards_provider.dart`
- Modify: `test/providers/rewards_provider_test.dart`

- [ ] **Step 1: Add failing tests**

Append:

```dart
  group('consumeHint', () {
    test('returns freeSlot when slot > 0', () async {
      SharedPreferences.setMockInitialValues({'rewards.freeHintSlot': 1});
      final p = RewardsProvider();
      await p.load();

      final src = p.consumeHint();

      expect(src, HintSource.freeSlot);
      expect(p.freeHintSlot, 0);
    });

    test('returns purchased when slot empty and pool > 0', () async {
      SharedPreferences.setMockInitialValues({'rewards.purchasedHintCount': 2});
      final p = RewardsProvider();
      await p.load();

      final src = p.consumeHint();

      expect(src, HintSource.purchased);
      expect(p.purchasedHintCount, 1);
    });

    test('returns null when neither available', () async {
      final p = RewardsProvider();
      await p.load();

      expect(p.consumeHint(), isNull);
    });
  });

  test('addPurchasedHints increments pool', () async {
    final p = RewardsProvider();
    await p.load();

    p.addPurchasedHints(5);

    expect(p.purchasedHintCount, 5);
  });
```

- [ ] **Step 2: Run (expect failure)**

Run: `flutter test test/providers/rewards_provider_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Add to `RewardsProvider`:

```dart
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
```

- [ ] **Step 4: Run**

Run: `flutter test test/providers/rewards_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/rewards_provider.dart test/providers/rewards_provider_test.dart
git commit -m "feat: add consumeHint waterfall + addPurchasedHints"
```

---

## Task 8: Implement `incrementBonusCounter` + `markPremium`

**Files:**
- Modify: `lib/providers/rewards_provider.dart`
- Modify: `test/providers/rewards_provider_test.dart`

- [ ] **Step 1: Add failing tests**

Append:

```dart
  group('incrementBonusCounter', () {
    test('increments up to 10', () async {
      final p = RewardsProvider();
      await p.load();

      for (var i = 0; i < 9; i++) {
        p.incrementBonusCounter();
      }
      expect(p.bonusWordCounter, 9);
      expect(p.freeHintSlot, 0);

      p.incrementBonusCounter();

      expect(p.bonusWordCounter, 0, reason: 'resets after threshold');
      expect(p.freeHintSlot, 1, reason: 'earned one hint');
    });

    test('freezes at 10 if slot already full', () async {
      SharedPreferences.setMockInitialValues({
        'rewards.freeHintSlot': 1,
        'rewards.bonusWordCounter': 9,
      });
      final p = RewardsProvider();
      await p.load();

      p.incrementBonusCounter();

      expect(p.bonusWordCounter, 10, reason: 'frozen at threshold');
      expect(p.freeHintSlot, 1);

      p.incrementBonusCounter();

      expect(p.bonusWordCounter, 10);
    });
  });

  test('markPremium raises slot cap', () async {
    SharedPreferences.setMockInitialValues({
      'rewards.freeHintSlot': 1,
      'rewards.lastDailyClaimedOn': '2026-04-15',
    });
    final fakeNow = DateTime(2026, 4, 16);
    final p = RewardsProvider(clock: () => fakeNow);
    await p.load();

    p.markPremium();
    p.maybeRefillDailyHint();

    expect(p.premium, isTrue);
    expect(p.freeHintSlot, 2,
        reason: 'cap is now 3; today s refill can bump 1->2');
  });
```

- [ ] **Step 2: Run (fail)**

Run: `flutter test test/providers/rewards_provider_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Add:

```dart
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
      }
      // else keep at 10, slot is full; caller owns popup UX
    }
    notifyListeners();
    save();
  }

  /// Set premium flag. Does not itself refill — call
  /// `maybeRefillDailyHint()` or let the next level-start call do it.
  void markPremium() {
    if (premium) return;
    premium = true;
    notifyListeners();
    save();
  }
```

- [ ] **Step 4: Run**

Run: `flutter test test/providers/rewards_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/rewards_provider.dart test/providers/rewards_provider_test.dart
git commit -m "feat: add incrementBonusCounter + markPremium"
```

---

## Task 9: Stub `onLevelComplete` and `unlockAchievement` (Phase 3 fleshes them out)

**Files:**
- Modify: `lib/providers/rewards_provider.dart`
- Modify: `test/providers/rewards_provider_test.dart`

- [ ] **Step 1: Add failing tests**

Append:

```dart
  group('onLevelComplete (Phase 1 minimal)', () {
    test('updates highestCompletedLevel and currentLevel advance', () async {
      final p = RewardsProvider();
      await p.load();

      p.onLevelComplete(
        mode: LanguageMode.russian,
        levelId: 3,
        pendingScore: 150,
      );

      expect(p.highestCompletedLevel[LanguageMode.russian], 3);
      expect(p.currentLevel[LanguageMode.russian], 4);
    });

    test('records best score and lifetime score', () async {
      final p = RewardsProvider();
      await p.load();

      p.onLevelComplete(
        mode: LanguageMode.english,
        levelId: 1,
        pendingScore: 80,
      );
      p.onLevelComplete(
        mode: LanguageMode.english,
        levelId: 1,
        pendingScore: 120,
      );

      expect(p.levelBestScore[LanguageMode.english]![1], 120);
      expect(p.lifetimeScore[LanguageMode.english], 200);
    });

    test('does not downgrade best score', () async {
      final p = RewardsProvider();
      await p.load();

      p.onLevelComplete(
        mode: LanguageMode.russian,
        levelId: 1,
        pendingScore: 150,
      );
      p.onLevelComplete(
        mode: LanguageMode.russian,
        levelId: 1,
        pendingScore: 80,
      );

      expect(p.levelBestScore[LanguageMode.russian]![1], 150);
    });
  });

  test('unlockAchievement adds id and is idempotent', () async {
    final p = RewardsProvider();
    await p.load();

    p.unlockAchievement('first_word');
    p.unlockAchievement('first_word');
    p.unlockAchievement('first_level');

    expect(p.achievementsUnlocked, {'first_word', 'first_level'});
  });
```

- [ ] **Step 2: Run (fail)**

Run: `flutter test test/providers/rewards_provider_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Add:

```dart
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
```

- [ ] **Step 4: Run**

Run: `flutter test test/providers/rewards_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/rewards_provider.dart test/providers/rewards_provider_test.dart
git commit -m "feat: add onLevelComplete + unlockAchievement (Phase 1 minimal)"
```

---

## Task 10: Add `muted` field to `SettingsProvider`

**Files:**
- Modify: `lib/providers/settings_provider.dart`
- Modify: `test/providers/settings_provider_test.dart` (create if missing)

- [ ] **Step 1: Read current file**

Open `lib/providers/settings_provider.dart` and confirm it currently has `languageMode` with a `setLanguageMode` method + `load()` + a `settings.languageMode` SharedPreferences key.

- [ ] **Step 2: Write failing test**

Create or extend `test/providers/settings_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/providers/settings_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('muted defaults to false', () async {
    final p = SettingsProvider();
    await p.load();

    expect(p.muted, isFalse);
  });

  test('setMuted persists and notifies', () async {
    final p = SettingsProvider();
    await p.load();

    var ticks = 0;
    p.addListener(() => ticks++);

    await p.setMuted(true);

    expect(p.muted, isTrue);
    expect(ticks, 1);

    final p2 = SettingsProvider();
    await p2.load();
    expect(p2.muted, isTrue);
  });
}
```

- [ ] **Step 3: Run (fail)**

Run: `flutter test test/providers/settings_provider_test.dart`
Expected: FAIL — no `muted`.

- [ ] **Step 4: Implement**

In `lib/providers/settings_provider.dart`, add the `muted` field + setter + load/save. Example shape:

```dart
  static const _kMuted = 'settings.muted';

  bool _muted = false;
  bool get muted => _muted;

  Future<void> setMuted(bool value) async {
    if (_muted == value) return;
    _muted = value;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kMuted, value);
  }
```

In the existing `load()` method, add:

```dart
    _muted = sp.getBool(_kMuted) ?? false;
```

- [ ] **Step 5: Run**

Run: `flutter test test/providers/settings_provider_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/settings_provider.dart test/providers/settings_provider_test.dart
git commit -m "feat: persist mute toggle in SettingsProvider"
```

---

## Task 11: Add settings-screen string keys

**Files:**
- Modify: `lib/l10n/strings_en.dart`
- Modify: `lib/l10n/strings_ru.dart`

- [ ] **Step 1: Add the keys**

In `strings_en.dart`, add (matching the existing class structure):

```dart
  String get settingsTitle => 'Settings';
  String get settingsLanguage => 'Language';
  String get settingsRules => 'How to play';
  String get settingsMute => 'Mute sounds';
  String get settingsRemoveAds => 'Remove ads';
  String get settingsRestore => 'Restore purchases';
  String get settingsPrivacy => 'Privacy policy';
```

In `strings_ru.dart`, add:

```dart
  String get settingsTitle => 'Настройки';
  String get settingsLanguage => 'Язык';
  String get settingsRules => 'Как играть';
  String get settingsMute => 'Выключить звук';
  String get settingsRemoveAds => 'Убрать рекламу';
  String get settingsRestore => 'Восстановить покупки';
  String get settingsPrivacy => 'Политика конфиденциальности';
```

- [ ] **Step 2: Verify analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/strings_en.dart lib/l10n/strings_ru.dart
git commit -m "i18n: add settings screen string keys (ru+en)"
```

---

## Task 12: Create `SettingsRow` widget

**Files:**
- Create: `lib/widgets/settings_row.dart`

- [ ] **Step 1: Write the widget**

Create `lib/widgets/settings_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A single row in the settings screen. Styled per Soviet-Notebook design:
/// navy label on cream, optional trailing widget (switch or chevron),
/// optional onTap. If [enabled] is false, the whole row is dimmed and taps
/// are swallowed.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: enabled ? AppTheme.foreground : AppTheme.muted,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    if (!enabled || onTap == null) {
      return Opacity(opacity: enabled ? 1 : 0.5, child: content);
    }

    return InkWell(
      onTap: onTap,
      child: Semantics(button: true, label: label, child: content),
    );
  }
}
```

Note: If `AppTheme.bodyMedium` does not exist in the existing theme, substitute whatever the nearest Soviet-Notebook body style is (read `lib/theme/app_theme.dart` first).

- [ ] **Step 2: Run analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/settings_row.dart
git commit -m "feat: add SettingsRow widget for settings screen"
```

---

## Task 13: Write failing test for SettingsScreen scaffold

**Files:**
- Create: `test/screens/settings_screen_test.dart`

- [ ] **Step 1: Write the test**

Create `test/screens/settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/providers/settings_provider.dart';
import 'package:slova_iz_slova/screens/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child, SettingsProvider settings) {
    return MaterialApp(
      home: ChangeNotifierProvider.value(
        value: settings,
        child: child,
      ),
    );
  }

  testWidgets('renders six stub rows', (tester) async {
    final settings = SettingsProvider();
    await settings.load();

    await tester.pumpWidget(wrap(const SettingsScreen(), settings));

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('How to play'), findsOneWidget);
    expect(find.text('Mute sounds'), findsOneWidget);
    expect(find.text('Remove ads'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
  });

  testWidgets('Phase-1-disabled rows are dimmed', (tester) async {
    final settings = SettingsProvider();
    await settings.load();

    await tester.pumpWidget(wrap(const SettingsScreen(), settings));

    // Mute row is Phase 1-disabled (enabled in Phase 4). Remove-ads / Restore /
    // Privacy also disabled here.
    final muteRow = find.ancestor(
      of: find.text('Mute sounds'),
      matching: find.byType(Opacity),
    );
    expect(muteRow, findsOneWidget);
  });
}
```

- [ ] **Step 2: Run (fail)**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: FAIL — `settings_screen.dart` not found.

- [ ] **Step 3: Commit failing test**

```bash
git add test/screens/settings_screen_test.dart
git commit -m "test: add failing SettingsScreen scaffold tests"
```

---

## Task 14: Implement `SettingsScreen` scaffold

**Files:**
- Create: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Write the screen**

Create `lib/screens/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/grid_paper_background.dart';
import '../widgets/rules_modal.dart';
import '../widgets/settings_row.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final strings = settings.languageMode == LanguageMode.russian
        ? StringsRu()
        : StringsEn();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.foreground),
        title: Text(
          strings.settingsTitle,
          style: AppTheme.titleMedium,
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GridPaperBackground()),
          SafeArea(
            child: ListView(
              children: [
                SettingsRow(
                  label: strings.settingsLanguage,
                  onTap: () => _openLanguageSheet(context, settings),
                  trailing: Text(
                    settings.languageMode?.displayName ?? '',
                    style: AppTheme.bodySmall,
                  ),
                ),
                SettingsRow(
                  label: strings.settingsRules,
                  onTap: () => showRulesModal(context),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppTheme.foreground),
                ),
                // Phase 1 disabled; Phase 4 enables.
                SettingsRow(
                  label: strings.settingsMute,
                  enabled: false,
                  trailing: Switch(value: settings.muted, onChanged: null),
                ),
                // Phase 5 enables.
                SettingsRow(
                  label: strings.settingsRemoveAds,
                  enabled: false,
                  trailing: const Icon(Icons.chevron_right,
                      color: AppTheme.foreground),
                ),
                SettingsRow(
                  label: strings.settingsRestore,
                  enabled: false,
                  trailing: const Icon(Icons.chevron_right,
                      color: AppTheme.foreground),
                ),
                SettingsRow(
                  label: strings.settingsPrivacy,
                  enabled: false,
                  trailing: const Icon(Icons.chevron_right,
                      color: AppTheme.foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openLanguageSheet(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in LanguageMode.values)
              ListTile(
                title: Text(mode.displayName),
                leading: Text(mode.flag,
                    style: const TextStyle(fontSize: 22)),
                onTap: () async {
                  await settings.setLanguageMode(mode);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
```

Notes:
- If any referenced `AppTheme.*` style doesn't exist, substitute the nearest existing equivalent — read `lib/theme/app_theme.dart` first.
- If `showRulesModal` is defined differently in the v1.0 codebase, adjust the import and call.
- If `LanguageMode.displayName` / `.flag` already exist (they do, per `CLAUDE.md`), this compiles as-is.

- [ ] **Step 2: Run the settings-screen test**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: PASS.

- [ ] **Step 3: Run all tests + analyze**

Run: `flutter analyze && flutter test`
Expected: PASS, zero analyze issues.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: add SettingsScreen scaffold with six rows"
```

---

## Task 15: Wire `RewardsProvider` + `AdGateway` into provider tree

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app.dart` (only if needed)

- [ ] **Step 1: Read current main.dart**

Read `lib/main.dart` to confirm the existing provider tree shape.

- [ ] **Step 2: Modify main.dart**

In `main()`, before `runApp`, load `RewardsProvider`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final settings = SettingsProvider();
  await settings.load();

  final rewards = RewardsProvider();
  await rewards.load();

  final AdGateway adGateway = NoopAdGateway();
  await adGateway.initialize();

  await AudioService.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<RewardsProvider>.value(value: rewards),
        Provider<AdGateway>.value(value: adGateway),
        // GameProvider stays whatever it is today; Phase 2 swaps it to
        // ChangeNotifierProxyProvider<RewardsProvider, GameProvider>.
        ChangeNotifierProvider<GameProvider>(create: (_) => GameProvider()),
      ],
      child: const WordsApp(),
    ),
  );
}
```

Add the needed imports at top:

```dart
import 'providers/rewards_provider.dart';
import 'services/ad_gateway.dart';
import 'services/audio_service.dart';
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Run full test suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat: register RewardsProvider + AdGateway in provider tree"
```

---

## Task 16: Re-entry flow — skip language picker when set

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Read current home_screen.dart**

Read `lib/screens/home_screen.dart`. The current behaviour shows the language-picker landing UI unconditionally.

- [ ] **Step 2: Write failing test**

Create `test/screens/home_screen_reentry_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/models/language_mode.dart';
import 'package:slova_iz_slova/providers/game_provider.dart';
import 'package:slova_iz_slova/providers/settings_provider.dart';
import 'package:slova_iz_slova/screens/home_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(SettingsProvider s) {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: s),
          ChangeNotifierProvider<GameProvider>(create: (_) => GameProvider()),
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

    // The language picker UI should be present. The two language cards are
    // the v1.0 landing. Find by any text your v1.0 picker uses; adapt as
    // needed.
    expect(find.byKey(const ValueKey('language-picker')), findsOneWidget);
  });

  testWidgets('skips language picker when languageMode set', (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.languageMode': 'russian',
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
```

- [ ] **Step 3: Run (fail)**

Run: `flutter test test/screens/home_screen_reentry_test.dart`
Expected: FAIL.

- [ ] **Step 4: Split HomeScreen into `_LanguagePicker` and `_HomeMain`**

Refactor `lib/screens/home_screen.dart` so its `build` returns:

```dart
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (settings.languageMode == null) {
      return const _LanguagePicker(key: ValueKey('language-picker'));
    }
    return _HomeMain(
      key: const ValueKey('home-main'),
      mode: settings.languageMode!,
    );
  }
```

Move the existing widget tree from `build` into `_LanguagePicker` (keep keys and strings exactly as they are today). In `_HomeMain`, render the existing post-landing UI (start-game CTA, rules button, etc.), plus a gear icon in the top-right corner that routes to `SettingsScreen`:

```dart
IconButton(
  icon: const Icon(Icons.settings, color: AppTheme.foreground),
  onPressed: () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
  ),
),
```

Exact shape depends on current v1.0 home layout — preserve all existing children; only add the conditional and the gear icon.

- [ ] **Step 5: Run test**

Run: `flutter test test/screens/home_screen_reentry_test.dart`
Expected: PASS.

- [ ] **Step 6: Manual sanity check**

Run: `flutter run` (on device or emulator). Verify:
1. Fresh install (or wipe app data) shows language picker.
2. Pick Russian.
3. Kill and relaunch app. Language picker is skipped; `_HomeMain` appears.
4. Tap gear icon → settings screen opens.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/home_screen.dart test/screens/home_screen_reentry_test.dart
git commit -m "feat: re-entry flow skips language picker when set + gear icon"
```

---

## Task 17: Final phase verification

- [ ] **Step 1: Run everything**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`, all tests pass.

- [ ] **Step 2: Smoke test on device**

Run: `flutter run`
Checklist:
- App boots to language picker first time.
- After picking, gameplay is unchanged vs v1.0.
- Relaunch skips picker.
- Settings screen accessible via gear icon; all 6 rows render; 4 are visibly disabled.

- [ ] **Step 3: Verify v1.1 contracts are respected**

Open `docs/V1_1_CONTRACTS.md` and confirm every field/method name and persistence key in `rewards_provider.dart` matches exactly. Fix any drift before closing the phase.

- [ ] **Step 4: Final commit / tag**

```bash
git tag phase-1-foundations-complete
```

---

## Exit criteria recap

- `RewardsProvider` persists full v1.1 state across launches. Migration from bare v1.0 SharedPreferences (only `settings.languageMode`) produces clean defaults.
- `AdGateway` + `NoopAdGateway` live under `lib/services/` and are reachable via `context.read<AdGateway>()`.
- `AudioService.instance` exists with no-op method bodies.
- Settings screen opens from home gear icon; 6 stub rows render.
- Re-entry flow: language picker only shows on first launch (per-install).
- Zero `flutter analyze` issues. All new tests pass. No v1.0 gameplay regressions.

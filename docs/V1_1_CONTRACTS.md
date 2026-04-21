# v1.1 Contracts

Single source of truth for cross-phase names. Every per-phase plan in `docs/superpowers/plans/` must use the exact spellings below. If a name needs to change, change it here first and propagate.

---

## RewardsProvider (new, Phase 1)

Location: `lib/providers/rewards_provider.dart`. Extends `ChangeNotifier`. Registered above `GameProvider` in the provider tree so `GameProvider` can read it.

### Fields (all persisted)

| Field | Type | Notes |
|---|---|---|
| `schemaVersion` | `int` | Current: `1`. Bumps when persistence shape changes. |
| `freeHintSlot` | `int` | 0..cap. Cap = 1 for free tier, 3 for premium. |
| `bonusWordCounter` | `int` | 0..10. Increments per bonus word found. Freezes at 10 if slot is full. |
| `lastDailyClaimedOn` | `DateTime?` | Local midnight of last daily-refill claim. |
| `purchasedHintCount` | `int` | Pool filled by hint-pack IAP or rewarded ad. |
| `premium` | `bool` | True if user has purchased the remove-ads IAP. |
| `streakCount` | `int` | Consecutive days with ≥1 level completed. |
| `streakLastPlayedOn` | `DateTime?` | Local date of last streak-counting completion. |
| `achievementsUnlocked` | `Set<String>` | Achievement IDs (see Phase 3). |
| `currentLevel` | `Map<LanguageMode, int>` | Per-language, 1-indexed. Defaults to 1. |
| `highestCompletedLevel` | `Map<LanguageMode, int>` | 0 if none completed. |
| `levelBestScore` | `Map<LanguageMode, Map<int, int>>` | Best score by language + levelId. |
| `lifetimeScore` | `Map<LanguageMode, int>` | Cumulative score across sessions. |

### Methods

```dart
Future<void> load();                            // From shared_preferences; run migrations
Future<void> save();                            // Persist all fields

void maybeRefillDailyHint();                    // Call on app resume + level start
bool get canUseHint;                            // Has free slot or purchased > 0
HintSource? consumeHint();                      // Returns source used, or null if none
void addPurchasedHints(int n);                  // Rewarded-ad or IAP hint-pack
void incrementBonusCounter();                   // On bonus word found
void markPremium();                             // On premium IAP success; raises slot cap
void onLevelComplete({
  required LanguageMode mode,
  required int levelId,
  required int pendingScore,
});
void unlockAchievement(String id);
```

### Enum

```dart
enum HintSource { freeSlot, purchased, rewardedAd }
```

### Persistence keys (in shared_preferences)

All under `rewards.` prefix plus existing `settings.` prefix:

```
rewards.schemaVersion         int
rewards.freeHintSlot          int
rewards.bonusWordCounter      int
rewards.lastDailyClaimedOn    String (ISO-8601 date, e.g. "2026-04-16")
rewards.purchasedHintCount    int
rewards.premium               bool
rewards.streakCount           int
rewards.streakLastPlayedOn    String (ISO-8601 date)
rewards.achievementsUnlocked  String (JSON array of IDs)
rewards.currentLevel.ru       int
rewards.currentLevel.en       int
rewards.highestCompletedLevel.ru  int
rewards.highestCompletedLevel.en  int
rewards.levelBestScore.ru     String (JSON map: "levelId" -> score)
rewards.levelBestScore.en     String (JSON map)
rewards.lifetimeScore.ru      int
rewards.lifetimeScore.en      int

settings.languageMode         String (existing)
settings.muted                bool   (new, Phase 4)
```

---

## AdGateway (new, Phase 1)

Location: `lib/services/ad_gateway.dart`.

```dart
abstract class AdGateway {
  Future<void> initialize();
  Future<void> loadInterstitial();
  /// Returns true if an interstitial was shown.
  Future<bool> showInterstitial();
  Future<void> loadRewarded();
  /// Calls onReward if the user watched to completion. Returns true if the ad played at all.
  Future<bool> showRewarded({required VoidCallback onReward});
}
```

Implementations:
- `NoopAdGateway` (Phase 1) — logs to debugPrint, `showInterstitial` returns false, `showRewarded` calls `onReward()` immediately and returns true. Used in dev, tests, and until MobileAds is wired.
- `MobileAdsGateway` (Phase 5) — real `google_mobile_ads` implementation.

Registered in provider tree as `Provider<AdGateway>` so consumers can `context.read<AdGateway>()`.

---

## AudioService (new, Phase 1 skeleton → Phase 4 real)

Location: `lib/services/audio_service.dart`. Pattern: **not a provider**, singleton reached via `AudioService.instance`. Rationale: UI widgets should not rebuild when audio state changes; it's fire-and-forget.

```dart
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  Future<void> initialize();   // Preload clips (Phase 4). No-op in Phase 1.
  void setMuted(bool muted);   // Read by every play*() call.
  bool get isMuted;

  Future<void> playTap();
  Future<void> playSuccess();
  Future<void> playError();
  Future<void> playLevelComplete();
  Future<void> playHintReveal();
  Future<void> playFreeHintEarned();
  Future<void> playBonusRefill();
}
```

Mute state mirrors `SettingsProvider.muted` — `SettingsProvider` writes through to `AudioService.setMuted` on change.

---

## AnalyticsService (new, Phase 6)

Location: `lib/services/analytics_service.dart`. Singleton. Wraps `FirebaseAnalytics.instance`.

```dart
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  Future<void> initialize();
  Future<void> logEvent(String name, {Map<String, Object?>? params});
  Future<void> setUserProperty(String name, String? value);
}
```

Event names are flat snake_case, matching GDD §10.4. Canonical list:
`app_open`, `level_start`, `level_complete`, `level_abandon`, `word_found`, `bonus_found`, `hint_used`, `hint_denied`, `free_hint_earned`, `free_hint_refilled`, `ad_interstitial_shown`, `ad_rewarded_shown`, `ad_rewarded_completed`, `ad_rewarded_abandoned`, `iap_premium_purchased`, `iap_hintpack_purchased`, `iap_restore_clicked`, `iap_restore_succeeded`, `streak_increment`, `streak_broken`, `achievement_unlocked`, `language_changed`, `mute_toggled`, `settings_opened`, `levelpicker_opened`, `trophies_opened`, `rules_opened`, `library_completed`, `replay_mode_entered`, `tile_shuffled`, `word_cleared`, `ugc_crash` (via Crashlytics, logged here too for fan-out), `remoteconfig_fetched`, `consent_att_result`, `consent_ump_result`.

---

## RemoteConfigService (new, Phase 6)

Location: `lib/services/remote_config_service.dart`. Singleton. Wraps `FirebaseRemoteConfig`.

```dart
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  Future<void> initialize();        // fetchAndActivate with 1h minimum fetch interval
  int get interstitialLevelCadence; // default 3
  int get bonusRefillThreshold;     // default 10
  int get freeHintSlotCapFree;      // default 1
  int get freeHintSlotCapPremium;   // default 3
  int get bonusWordFlatScore;       // default 15
  bool get rewardedAdsEnabled;      // default true
  bool get interstitialAdsEnabled;  // default true
  String get admobInterstitialIdIos;
  String get admobInterstitialIdAndroid;
  String get admobRewardedIdIos;
  String get admobRewardedIdAndroid;
}
```

All scoring and cadence constants are read through this service — never hardcoded at call sites after Phase 6.

---

## GameState changes (Phase 2)

Current `GameState` (from `lib/models/game_state.dart`) gains:

```dart
int pendingScore;               // Replaces v1.0 use of `score` as session total
Set<String> revealedTileIds;    // Tile IDs revealed by hint (for underline treatment)
```

The existing `score` field is **removed** from `GameState`. Session score lives in `pendingScore`; banked scores live in `RewardsProvider`.

The existing `hintsRemaining: int` field is **removed** from `GameState`. Hint availability comes from `RewardsProvider.canUseHint`.

---

## GameLevel changes (Phase 7)

```dart
int? difficulty;                // 1..5, null until level re-audited
```

---

## LevelLoader changes (Phase 0 / Phase 3)

```dart
class LevelNotFoundException implements Exception {
  final int requestedLevel;
  final int librarySize;
  LevelNotFoundException(this.requestedLevel, this.librarySize);
}

// generateLevel throws LevelNotFoundException when levelNumber > defs.length
```

No silent modulo wrap. Caller (`GameProvider.nextLevel`) catches and routes to library-complete screen.

---

## Screens (new in v1.1)

| Screen | File | Phase |
|---|---|---|
| SettingsScreen | `lib/screens/settings_screen.dart` | 1 (scaffold) → 4/5 (wired) |
| LevelPickerScreen | `lib/screens/level_picker_screen.dart` | 3 |
| TrophiesScreen | `lib/screens/trophies_screen.dart` | 3 |
| LibraryCompleteScreen | `lib/screens/library_complete_screen.dart` | 3 |

---

## Strings keys (new, across v1.1)

Every new user-facing string is added to both `strings_ru.dart` and `strings_en.dart`. New keys (full list assembled here so no two phases collide):

```
settingsTitle, settingsLanguage, settingsRules, settingsMute,
settingsRemoveAds, settingsRestore, settingsPrivacy,
levelPickerTitle, levelPickerLocked, levelPickerBestScore,
trophiesTitle, trophiesLocked, trophiesUnlocked,
libraryCompleteTitle, libraryCompleteBody, libraryCompleteReplay, libraryCompleteClose,
freeHintEarnedTitle, freeHintEarnedBody,
bonusCounterLabel, bankedHintsLabel,
rewardedAdPromptTitle, rewardedAdPromptBody, rewardedAdPromptWatch, rewardedAdPromptNo,
premiumPitchTitle, premiumPitchBody, premiumPitchCta, premiumPitchRestore,
hintPackPitchTitle, hintPackPitchBody, hintPackPitchCta,
attConsentBody, umpConsentBody,
streakDaysLabel,
replayModeBanner,
```

Plus rewritten: `rulesHint`, `rulesScore` (Phase 2, to reflect new economy).

---

## Achievements (Phase 3)

14 starter IDs, defined in `lib/data/achievements.dart`:

```
first_word            — find your first word
first_bonus           — find your first bonus word
first_level           — complete level 1
level_10              — complete level 10
level_25              — complete level 25
level_50              — complete level 50
streak_3              — 3-day streak
streak_7              — 7-day streak
streak_30             — 30-day streak
hint_free             — earn a hint via the bonus accumulator
no_hint_level         — complete a level without using a hint
perfect_level         — find every bonus word in a level
bilingual             — complete at least one level in both languages
collector             — unlock 10 achievements
```

---

## Package versions

Lockstep versions for v1.1 (pinned in each phase plan):

```
provider ^6.1.2
flutter_animate ^4.5.0
google_fonts ^6.2.1
shared_preferences ^2.2.3
flutter_localizations (from sdk)
google_mobile_ads ^5.1.0             # Phase 5
in_app_purchase ^3.2.0               # Phase 5
audioplayers ^6.0.0                  # Phase 4
firebase_core ^3.3.0                 # Phase 6
firebase_analytics ^11.2.1           # Phase 6
firebase_remote_config ^5.1.1        # Phase 6
firebase_crashlytics ^4.0.4          # Phase 6
app_tracking_transparency ^2.0.4     # Phase 5
```

Engineer's prerogative: bump to latest stable at time of PR if no breaking changes.

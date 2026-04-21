# GDD Audit — v1.0 actual vs GDD scope

Audit date: 2026-04-16. Based on `main` branch of `github.com/robchambo/words-from-a-word`.

Legend: ✅ built · ❌ missing · ⚠ partial / needs work · 🔍 discrepancy found between GDD and code

---

## 1. What's built (matches GDD)

These items are in v1.0 and match what the GDD describes as current state:

- ✅ Flutter stack, Dart 3.11, portrait lock, provider state management.
- ✅ Soviet Notebook design system (all tokens present in `lib/theme/app_theme.dart`).
- ✅ Two providers: `GameProvider`, `SettingsProvider`.
- ✅ Two screens: `home_screen.dart`, `game_screen.dart`.
- ✅ Eight widgets including `letter_tile`, `tile_picker`, `word_slots`, `word_slot_item`, `level_complete_overlay`, `rules_modal`, `stamp_badge`, `grid_paper_background`.
- ✅ 23 Russian levels + 20 English levels (array lengths confirmed).
- ✅ `shared_preferences` persists language mode.
- ✅ `google_fonts` package for runtime font loading.
- ✅ `flutter_animate` for animations.
- ✅ Haptics via `HapticFeedback` (D3).
- ✅ Test file exists (`test/widget_test.dart`, 113 lines).

---

## 2. Discrepancies between GDD and code

**Resolved 2026-04-16 in Phase 0 of the v1.1 roadmap.** See commit history, GDD §5.1, §5.7, §9.1, and `DECISIONS.md` D17.

- ✅ **Level JSON schema has no `id` field.** GDD §5.1 example corrected — the `"id": 1` line removed. Level ID is derived from `LevelLoader.generateLevel(levelNumber)`. Decision logged in D17.
- ✅ **End-of-library silently loops.** Confirmed v1.0 bug (not a feature). GDD §5.7 updated to describe the v1.1 fix: explicit library-complete screen with free-mode replay. Code change scheduled for Phase 3. Decision logged in D17.
- ✅ **`confetti` package referenced in GDD §9.1 is not in `pubspec.yaml`.** Verified by reading `level_complete_overlay.dart` — confetti is 18 rotating rectangles home-rolled with `flutter_animate` (`_Confetti` widget, lines 101-149). GDD §9.1 corrected to remove the spurious `confetti` package bullet.
- ✅ **Rules modal hint copy not verified as matching v1.0 mechanic.** Verified by reading `strings_en.dart` line 41-42: copy reads "tap the lightbulb to reveal the first letter of the next unsolved word. 3 hints per level." This accurately describes the v1.0 mechanic. Rewrite for the new hint system is tracked in Phase 2 of the roadmap.

---

## 3. Missing — v1.1 scope

Organised by GDD §12.3 launch-version workstreams. Every item here is documented in the GDD but absent from code.

### 3.1 Product features

- ❌ **Re-entry flow** — home screen still shows language picker every launch, despite `SettingsProvider` persisting the choice (GDD §3, §6.1).
- ❌ **Level picker screen** — no file exists (GDD §6.2).
- ❌ **Per-level best score** tracking (GDD §6.3).
- ❌ **Lifetime cumulative score** tracking (GDD §6.3).
- ❌ **Streaks** — no logic or persistence (GDD §6.4).
- ❌ **Achievements** — no logic, no trophies screen, no 14-badge starter set (GDD §6.6).

### 3.2 Scoring & hint economy rework

- ❌ **Bonus-word flat 15-pt scoring** — current code uses the regular length-based formula for bonus words (GDD §4.4).
- ❌ **Pending-and-bank scoring** — current code updates `score` immediately on each find (GDD §4.4).
- ❌ **Safe-letter hint algorithm** — current `useHint()` at `lib/providers/game_provider.dart:165` still uses the v1.0 first-letter-of-next-word logic (GDD §4.5).
- ❌ **Free-hint slot system** — no `freeHintSlot`, `bonusWordCounter`, or `lastDailyClaimedOn` state; `hintsRemaining: int` still in `GameState` (GDD §4.5).
- ❌ **Slot pre-fill reveal** with underline treatment (GDD §4.5, §7.5).
- ❌ **Celebratory popup** on bonus-word refill (GDD §4.5).
- ❌ **Top-strip progress indicator** for bonus counter + banked hints (GDD §4.5, §7.5).

### 3.3 Monetisation

- ❌ **`google_mobile_ads`** — commented out in `pubspec.yaml`; no `AdGateway`, no `MobileAdsGateway` (GDD §8.5, §9.3).
- ❌ **`in_app_purchase`** — not in `pubspec.yaml`; no IAP products configured (GDD §8.6).
- ❌ **Premium IAP** ($2.99) — no product, no entitlement flag, no UI (GDD §8.1).
- ❌ **Hint pack IAP** ($0.99 × 5) — no product, no pool (GDD §8.1).
- ❌ **Restore purchases** — no UI, no handler (GDD §8.6).
- ❌ **Interstitial ads** between levels (GDD §8.3).
- ❌ **Rewarded ads** for hints (GDD §8.4).
- ❌ **Consent flows** (ATT / UMP) (GDD §8.7).

### 3.4 Analytics & tuning

- ❌ **Firebase** — no `firebase_core`, `firebase_analytics`, `firebase_remote_config`, `firebase_crashlytics` (GDD §10.1).
- ❌ **Event taxonomy** — none of the 35+ events implemented (GDD §10.4).
- ❌ **Remote Config** wrapping for any provisional numbers (GDD §10.5).
- ❌ **Crashlytics** (GDD §10.7).

### 3.5 Content

- ⚠ **Level count** — 23 RU + 20 EN; launch bar is 50 / 50. Gaps: **27 RU + 30 EN levels** need authoring and validation (GDD §5.6, §12.8).
- ❌ **`difficulty: 1..5`** field in level schema — not present in any JSON (GDD §5.2).
- ❌ **Deliberate difficulty ordering** — current ordering is arbitrary (GDD §5.3, confirmed earlier by Rob).

### 3.6 Accessibility (GDD §11)

- ❌ **Contrast audit** — amber `accent` fails AA at 2.4:1 on cream. No code changes to avoid it on body text (GDD §11.2).
- ❌ **Tap-target audit** — action buttons (Shuffle, Hint, Submit, Clear) not confirmed at ≥ 44×44 (GDD §11.3).
- ❌ **Dynamic type** — no `MediaQuery.textScaler` usage anywhere in `lib/` (GDD §11.4).
- ❌ **Reduced motion** — no `MediaQuery.disableAnimations` usage anywhere in `lib/` (GDD §11.5).
- ❌ **Screen readers** — no `Semantics` widgets found in `lib/` (GDD §11.6).
- ❌ **A11y testing plan** — 5-step pre-launch gate not executed (GDD §11.7).
- ❌ **Russian pluralisation helper** in `StringsRu` (GDD §11.8).

### 3.7 Audio

- ❌ **`audioplayers` package** — not in `pubspec.yaml` (GDD §7.6).
- ❌ **`assets/audio/` folder** — does not exist; no SFX clips bundled (GDD §7.6).
- ❌ **`AudioService` singleton** — not present; no `lib/services/` folder (GDD §7.6, §9.3).
- ❌ **Mute toggle** — no setting, no UI (GDD §7.6).
- ❌ **Haptic extensions** (hint reveal, free-hint earned, level complete) not added (GDD §7.6).

### 3.8 Infrastructure

- ❌ **Settings screen** — no `settings_screen.dart`. Needed for mute toggle, remove-ads, restore purchases, language, rules (GDD §12.3).
- ❌ **`RewardsProvider`** — not present. Needs to own `freeHintSlot`, `bonusWordCounter`, `lastDailyClaimedOn`, `purchasedHintCount`, `premium`, `streakCount`, `streakLastPlayedOn`, `achievementsUnlocked`, `currentLevel.{ru,en}`, `highestCompletedLevel.{ru,en}`, `levelBestScore.{ru,en,levelId}`, `lifetimeScore.{ru,en}` (GDD §9.3, §9.6).
- ❌ **`AdGateway`** abstract + `NoopAdGateway` + `MobileAdsGateway` (GDD §9.3).
- ❌ **`AudioService`** singleton (GDD §9.3).
- ❌ **Persistence expansion** — 12+ new shared_preferences keys not written (GDD §9.6, §6.3).
- ❌ **Rules modal copy rewrite** for new hint system in both languages (GDD §7.5).
- ❌ **App icon** — platform folders exist (`ios/.../AppIcon.appiconset`, `android/.../mipmap-*`) but contents are Flutter defaults (not replaced with the final Soviet-Notebook icon).
- ❌ **Splash screen** — same: Flutter defaults.
- ❌ **CI** — no `.github/` folder, no GitHub Actions workflow (GDD §9.8, §12.3).

### 3.9 Store readiness

- ❌ **Store listing copy** in EN and RU.
- ❌ **Screenshots** prepared in both languages.
- ❌ **Data-safety declarations** drafted (GDD §10.8).
- ❌ **Privacy policy** published (implied by §10.8 but not explicitly documented in GDD — flag for roadmap).

---

## 4. Summary — scope of the v1.0 → v1.1 effort

Counting implementation items (not docs): **42 missing features or artifacts.** The work spans:

- **~15 new files** (settings screen, level picker, trophies screen, `RewardsProvider`, `AudioService`, `AdGateway` + impls, `RemoteConfigService`, `AnalyticsService`, `plurals_ru.dart`, 7 SFX assets, + tests).
- **Modifications to most existing `lib/` files** (scoring, hint algorithm, game state model, game screen, level loader schema bump, rules modal copy, letter tile and word slot widgets for reveal + a11y).
- **Content production**: 27 RU + 30 EN new levels (~57 author-days), plus difficulty tagging of existing 43 levels.
- **Binary ops**: app icon, splash screen, store listing copy, screenshots, privacy policy, data-safety forms.
- **Ads + IAP setup**: AdMob account, store products (Apple + Google) configured.
- **Firebase project** created and wired end-to-end.
- **GitHub Actions** workflow.

---

## 5. Recommended immediate actions

1. **Fix GDD discrepancies** (§2 above) so the doc is trustworthy as a brief — mainly the level `id` schema and the end-of-library wrap behaviour.
2. **Add a `docs/V1_1_PLAN.md`** that sequences the 42 items into implementation order, grouped into PR-sized chunks. The GDD is the *what*; this plan is the *how and when*. Without it, v1.1 is too big to execute safely.
3. **Start with foundations that unblock other work**: `RewardsProvider` + persistence schema, `AdGateway` skeleton, `AudioService` skeleton, settings screen scaffold. These have dependencies on nothing and unblock everything.

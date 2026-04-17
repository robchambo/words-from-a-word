# v1.1 Implementation Roadmap

> **For agentic workers:** This is the master plan. It sequences the 42 missing items from `docs/GDD_AUDIT.md` into 10 phases. Each phase will get its own detailed task-by-task plan in `docs/superpowers/plans/` when we're ready to build it.

**Goal:** Take the v1.0 game from its current state (core loop complete, single language session) to the full v1.1 scope documented in `docs/GDD.md` — ready for soft-launch to the Russian-speaking US diaspora on iOS + Android.

**Architecture:** Flutter + Provider. Introduce three new architectural pillars — `RewardsProvider` (persistence + hint economy + streaks + scores + achievements), `AdGateway` (abstract interface, Noop + MobileAds implementations), `AudioService` (singleton for SFX + mute). Reuse existing `GameProvider`, `SettingsProvider`, `GameEngine`, `LevelLoader` with targeted modifications. Firebase stack added for analytics, Remote Config, Crashlytics.

**Tech Stack:** Dart 3.11, Flutter, provider, flutter_animate, google_fonts, shared_preferences (existing). Adding: google_mobile_ads, in_app_purchase, audioplayers, firebase_core, firebase_analytics, firebase_remote_config, firebase_crashlytics, app_tracking_transparency.

---

## How this roadmap works

- **Phases are ordered by dependency.** Phase N can only safely start when Phase N-1 is done, with a few noted exceptions that can run in parallel.
- **Each phase produces working, testable software.** You can ship to TestFlight / internal-track at the end of any phase without breaking the game.
- **PR-sized chunks.** Each phase is broken into 3-8 PRs. Per-phase plans will enumerate them.
- **Gaps in GDD.** Four GDD-vs-code discrepancies (level JSON `id` field, end-of-library wrap, `confetti` claim, rules modal copy) are fixed in Phase 0.

---

## Phase 0 — Documentation cleanup (half a day)

**Why first:** The GDD is the source of truth for every later phase. If it's wrong, downstream work inherits the errors. Four small discrepancies from the audit must be reconciled before we start building.

**Scope:**
- Decide whether level JSON gets an explicit `id` field or GDD §5.1 drops the example `"id": 1`. Recommend: add `id` to JSON (keeps data self-describing).
- Fix the end-of-library behaviour. `LevelLoader.generateLevel` currently wraps silently via `(levelNumber - 1) % defs.length`. Replace with an explicit "library complete" result and decide UX (loop? show replay screen? show "more coming" message?). Document the choice in GDD §5.7 and DECISIONS.md (new entry D10).
- Verify `confetti` claim in GDD §9.1. Inspect `level_complete_overlay.dart` imports. If it's `flutter_animate` primitives, correct the GDD.
- Read `rules_modal.dart` and verify copy matches v1.0 mechanic. Note divergence for Phase 2's rewrite task.

**Exit criteria:** GDD is accurate as of v1.0. No discrepancies flagged.

**Blocks:** Phase 3 (level picker needs end-of-library decision), Phase 2 (rules modal rewrite needs to know current state).

---

## Phase 1 — Foundations (1-2 weeks)

**Why here:** Every remaining phase depends on at least one of these. If we build monetisation before `AdGateway` exists, we'll end up refactoring. If we build scoring rework before `RewardsProvider` owns the persistence, we'll scatter `shared_preferences` calls everywhere.

**Scope:**
1. **`RewardsProvider`** — new ChangeNotifier. Owns: `freeHintSlot`, `bonusWordCounter`, `lastDailyClaimedOn`, `purchasedHintCount`, `premium` (bool), `streakCount`, `streakLastPlayedOn`, `achievementsUnlocked` (Set), `currentLevel.{ru,en}`, `highestCompletedLevel.{ru,en}`, `levelBestScore.{ru,en,levelId}`, `lifetimeScore.{ru,en}`. All persisted to shared_preferences with a schema-version key. Write unit tests for load/save/migration from v1.0 state (only `languageMode` existed).
2. **`AdGateway`** abstract class + `NoopAdGateway` default implementation. Methods: `loadInterstitial()`, `showInterstitial()`, `loadRewarded()`, `showRewarded(onReward)`. No real ads yet — Noop just logs and calls `onReward()` immediately. Plumbed into provider tree.
3. **`AudioService`** singleton (no package yet). Methods: `playTap()`, `playSuccess()`, `playError()`, `playLevelComplete()`, `playHintReveal()`, `playFreeHintEarned()`, `setMuted(bool)`. Methods no-op for now (real audio lands in Phase 4).
4. **Settings screen scaffold.** New `lib/screens/settings_screen.dart` with stub rows for: language, rules, mute toggle (disabled), remove ads (disabled), restore purchases (disabled), privacy policy (disabled). Route from home screen via gear icon.
5. **Re-entry flow.** Home screen: if `SettingsProvider.languageMode != null` on startup, skip language picker and go straight to the last-played level. Language picker still accessible from settings.

**Exit criteria:** App launches, remembers language, `RewardsProvider` persists its state across launches (verified by unit test + manual test), settings screen opens, gameplay otherwise unchanged.

**Blocks:** Everything else.

---

## Phase 2 — Scoring & hint economy rework (2-3 weeks)

**Why here:** This is the most game-design-intensive change and touches `GameProvider` heavily. Doing it before monetisation means when we add rewarded ads, the hint economy they feed into already exists.

**Scope:**
1. **Pending-and-bank scoring.** `GameState` gains a `pendingScore` field. On word find, increment `pendingScore`. On level complete, move `pendingScore` → `score` and persist best/lifetime via `RewardsProvider`. On abandon mid-level, discard `pendingScore`.
2. **Bonus word flat 15-pt scoring.** `GameEngine.scoreWord` takes a `isBonus` flag; bonus words return a flat 15, not the length-based formula.
3. **Safe-letter hint algorithm.** Replace `useHint()`. Algorithm picks a letter from any unfound word such that revealing it does not complete that word (safety = remaining-unrevealed ≥ 2). If no safe letter exists across all unfound words, the hint button is disabled. Unit tests covering: hint picks safely; hint disabled when everything is one-letter-from-complete; hint works across multiple unfound words.
4. **Free-hint slot state.** `RewardsProvider` gets `freeHintSlot` (0 or 1, or 0..3 if premium), `bonusWordCounter` (int), `lastDailyClaimedOn` (ISO date string). Logic:
   - On level start: if `lastDailyClaimedOn` < today (local midnight) AND `freeHintSlot < cap`, refill by 1 and update `lastDailyClaimedOn`.
   - On bonus word found: increment `bonusWordCounter`. On reaching 10, decrement by 10 and if `freeHintSlot < cap` increment slot by 1. Counter freezes at 10 if slot full.
   - Hint waterfall on button press: free slot → purchased pool → rewarded ad.
5. **Slot pre-fill reveal.** `WordSlotItem` renders revealed letters with an underline treatment to distinguish from unrevealed.
6. **Celebratory popup** on bonus-word refill (10-bonus threshold). Reuse `flutter_animate` primitives.
7. **Top-strip progress indicator.** New widget showing bonus counter (x/10) and banked hints (free + purchased).
8. **Rules modal copy rewrite** in both `strings_ru.dart` and `strings_en.dart` to reflect new hint system.

**Exit criteria:** Playing a level never reveals a word via hint. Completing 10 bonus words banks a free hint. Free hint refills daily at local midnight. Abandoning a level loses pending score. Best/lifetime scores persist.

**Blocks:** Phase 3 (progression UI needs best/lifetime scores), Phase 5 (rewarded ads need the waterfall).

**Can run parallel with:** Phase 0 only.

---

## Phase 3 — Progression features (1-2 weeks)

**Why here:** Now that `RewardsProvider` owns scores and levels, we can surface them in UI.

**Scope:**
1. **Level picker screen.** New `lib/screens/level_picker_screen.dart`. Grid of stamp-badge tiles, one per level in current language. States: locked, unlocked-never-played, unlocked-in-progress, completed (with star count). Routes from home screen.
2. **Per-level best score** display in level picker and level complete overlay. Written on level complete if new best.
3. **Lifetime cumulative score** display on home screen + level picker header.
4. **Streaks.** Logic: if `streakLastPlayedOn` was yesterday and user completes a level today, increment. If gap > 1 day, reset to 1. Display on home screen.
5. **Achievements.** Starter 14-badge set per GDD §6.6. New `lib/screens/trophies_screen.dart`. Logic hooks into word-find, level-complete, streak-increment, hint-use events. Unit tests per achievement.
6. **End-of-library handling.** Implement Phase 0's decision.

**Exit criteria:** User can pick any unlocked level, see best score and lifetime score, earn achievements, see streak.

**Blocks:** Phase 9 (store screenshots need this UI).

---

## Phase 4 — Audio (3-5 days)

**Why here:** Low-risk, additive, testable in isolation. Slots in anywhere after Phase 1. Placed before monetisation because it's quick and polish-adjacent.

**Scope:**
1. Add `audioplayers` to `pubspec.yaml`.
2. Create `assets/audio/` folder with 7 SFX clips (tap, success, error, level-complete, hint-reveal, free-hint-earned, bonus-refill). Use freesound.org CC0 clips or commission.
3. Flesh out `AudioService` with real playback. Preload clips on service init.
4. Wire into events: tile tap, valid submit, invalid submit, level complete, hint reveal, free-hint earned, 10-bonus refill.
5. Mute toggle in settings screen, persisted via `SettingsProvider`.
6. Haptic extensions: add `HapticFeedback.lightImpact()` on hint reveal, `.mediumImpact()` on free-hint earned, `.heavyImpact()` on level complete (currently only on invalid submit).

**Exit criteria:** Audio plays for all events. Mute toggle silences everything. Haptics fire at new extension points.

---

## Phase 5 — Monetisation (2-3 weeks)

**Why here:** Needs `AdGateway` (Phase 1), hint waterfall (Phase 2), and settings screen (Phase 1). Heaviest third-party integration work.

**Scope:**
1. Uncomment `google_mobile_ads` in `pubspec.yaml`. Create AdMob account, register iOS + Android app IDs, set up test ad units.
2. **`MobileAdsGateway`** implementing `AdGateway`. Preload next interstitial during gameplay. Preload rewarded on demand.
3. **Interstitial** shown between levels (skip every 3rd completion or similar cadence — flag in Remote Config later).
4. **Rewarded ads** wired as final fallback in hint waterfall. Reward = 1 hint added to purchased pool.
5. Add `in_app_purchase` to `pubspec.yaml`. Configure products in App Store Connect + Google Play Console: `premium_no_ads_299`, `hint_pack_099_5`.
6. **Premium IAP.** On purchase: set `RewardsProvider.premium = true`, disable interstitials, raise free-hint slot cap from 1 to 3. Rewarded ads remain available (GDD decision: preserve ad option for premium when they run out).
7. **Hint pack IAP.** On purchase: increment `RewardsProvider.purchasedHintCount` by 5.
8. **Restore purchases** button in settings, wired to `in_app_purchase.restorePurchases()`.
9. **Consent flows.** iOS ATT prompt before any ad loads. UMP (Google's CMP) for GDPR where applicable. Gate ad initialization on consent result.

**Exit criteria:** Test user can buy premium, buy hint packs, restore, watch rewarded ad for hint, see interstitial between levels. ATT prompt appears on iOS first launch.

**Blocks:** Phase 9 (store listing mentions IAPs).

---

## Phase 6 — Analytics & tuning (1 week)

**Why here:** Can slot in after Phase 5 monetisation ships — you don't want to tune what you haven't built yet.

**Scope:**
1. Firebase project created. Add config files (`GoogleService-Info.plist`, `google-services.json`).
2. `firebase_core`, `firebase_analytics`, `firebase_remote_config`, `firebase_crashlytics` in `pubspec.yaml`.
3. **`AnalyticsService`** singleton. Emits 35+ events per GDD §10.4: `level_start`, `word_found`, `bonus_found`, `hint_used`, `hint_source`, `ad_shown`, `ad_rewarded`, `iap_purchased`, `iap_restored`, `streak_increment`, `achievement_unlocked`, etc.
4. **`RemoteConfigService`** wrapping provisional numbers: interstitial cadence, bonus-refill threshold, free-hint cap, hint-pack price display, ad unit IDs, feature flags.
5. **Crashlytics** initialized in `main.dart`. Dart errors + Flutter framework errors forwarded.

**Exit criteria:** Events visible in Firebase Analytics DebugView. Remote Config param changes take effect in-app after restart. A deliberate thrown exception appears in Crashlytics within 5 minutes.

---

## Phase 7 — Content (parallel to all phases, but final validation gate)

**Why here:** Level authoring is creative work that runs alongside engineering. But the "launch bar = 50 RU + 50 EN" decision means Phase 9 (store) can't ship until this is done.

**Scope:**
1. Add `difficulty: 1..5` field to level JSON schema. Update `LevelLoader` to parse it.
2. Author **27 new Russian levels** (currently 23, target 50). Validate each with `GameEngine.canFormWord()` script (same approach as D7).
3. Author **30 new English levels** (currently 20, target 50). Same validation.
4. Tag all 100 levels with `difficulty` 1-5.
5. Reorder both JSONs so difficulty climbs deliberately.

**Exit criteria:** 50 + 50 levels, all word-formation-validated, ordered by intended difficulty curve.

---

## Phase 8 — Accessibility (1 week)

**Why here:** Best done late so it audits the whole app, not just early screens. Rob's direction: best-effort with high standards, done before launch.

**Scope:**
1. **Contrast audit.** Amber `accent` (#F5A234) on cream `background` (#FFFEF0) fails AA at ~2.4:1. Policy: use amber only for iconography, badges, and large (≥18px bold) text. Never for body text. Audit every usage site.
2. **Tap-target audit.** Every button ≥ 44×44. Current Shuffle/Hint/Submit/Clear likely pass but haven't been confirmed. Add assertions or `InkWell` padding where needed.
3. **Dynamic type.** Wrap `Text` sizes with `MediaQuery.textScaler` so system font-size respect works. Audit for overflow.
4. **Reduced motion.** Read `MediaQuery.disableAnimations`. When true, disable `flutter_animate` transitions and confetti — use instant state changes instead.
5. **Semantics.** Add `Semantics` widgets to letter tiles, word slots, action buttons. Labels bilingual.
6. **Russian pluralisation helper.** `StringsRu.plural(n, one, few, many)` for "1 очко / 2 очка / 5 очков".
7. **A11y testing gate.** Manual test: VoiceOver on iOS, TalkBack on Android, 200% font size, reduced motion on. Document results in `docs/A11Y_AUDIT.md`.

**Exit criteria:** A11y audit doc shows pass on 5-step gate.

---

## Phase 9 — Store readiness (1 week)

**Why here:** Last. Needs final UI (for screenshots), final IAP products (for store listing), final content (for "50+ levels" claim).

**Scope:**
1. **App icon** — replace Flutter defaults with final Soviet Notebook design. Generate all iOS + Android sizes.
2. **Splash screen** — same.
3. **Store listing copy** (EN + RU) — title, subtitle, description, keywords, promo text.
4. **Screenshots** — 6 per language per platform (iPhone 6.7", 5.5", iPad 12.9", Android phone, tablet). Include localized text overlays.
5. **Data-safety declarations** — App Store privacy nutrition label + Play Data Safety form. Covers ads, analytics, IAP, no personal data collection per GDD §10.8.
6. **Privacy policy** — published to a web URL. Simple static page.
7. **CI via GitHub Actions** — `.github/workflows/ci.yml`. Runs `flutter analyze` + `flutter test` on PR. Optional: build APK on main.

**Exit criteria:** App submitted to TestFlight + Google Play internal track with full store metadata.

---

## Self-review checklist

- **Spec coverage:** All 42 items from `docs/GDD_AUDIT.md` are accounted for across Phases 0-9. Mapping: §3.1 → P1+P3, §3.2 → P2, §3.3 → P5, §3.4 → P6, §3.5 → P7, §3.6 → P8, §3.7 → P4, §3.8 → P1+P9, §3.9 → P9.
- **Dependency sanity:** RewardsProvider (P1) before scoring rework (P2); AdGateway (P1) before MobileAds (P5); settings screen scaffold (P1) before mute toggle (P4), remove-ads (P5), restore (P5); progression UI (P3) before store screenshots (P9).
- **Parallelisable work:** Phase 7 (content) runs alongside any engineering phase. Phase 0 (doc fixes) can run in parallel with Phase 1.

---

## What happens next

When you're ready to start building a phase, ask for the detailed plan:

- "Write the Phase 1 plan" → produces `docs/superpowers/plans/YYYY-MM-DD-phase-1-foundations.md` with task-by-task steps, exact file paths, test code, and commit points.
- Each per-phase plan will be executable with `superpowers:subagent-driven-development` or `superpowers:executing-plans`.

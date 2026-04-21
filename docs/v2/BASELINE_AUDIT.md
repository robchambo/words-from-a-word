# v2 Baseline Audit

**Date:** 2026-04-21
**Branch audited:** `v2` (at commit `327eaba`, which is `origin/median-calibration` + docs import)
**Purpose:** Establish ground truth about what v2 contains *before* starting v1.1 phase implementation. Feeds into the Stage 1 plan rewrites for Phases 2, 7, and 9.

---

## Summary

- ✅ **Analyzer clean.** `flutter analyze` — 0 issues (72.1s).
- ✅ **Tests green.** `flutter test` — 10/10 passing.
- ✅ **Flutter toolchain:** 3.41.6 stable / Dart 3.11.4.
- ❌ **No v1.1 contracts exist in code.** Every named entity in `docs/V1_1_CONTRACTS.md` is absent from `lib/`. Phase 1 introduces all of them from scratch.
- ⚠️ **Two plan-affecting baseline drifts** identified below — Phase 2 and Phase 7 need rewrites before execution (Phase 9 drift is lighter but also needs a pass).

---

## 0.1 Contract audit — `docs/V1_1_CONTRACTS.md` → `lib/`

Grep for every named class/enum/field from the contracts file across `lib/**/*.dart`:

| Contract | Expected location | Status |
|---|---|---|
| `RewardsProvider` | `lib/providers/rewards_provider.dart` | ❌ absent |
| `AdGateway` | `lib/services/ad_gateway.dart` | ❌ absent (`lib/services/` dir does not exist) |
| `NoopAdGateway` | same | ❌ absent |
| `AudioService` | `lib/services/audio_service.dart` | ❌ absent |
| `AnalyticsService` | `lib/services/analytics_service.dart` | ❌ absent |
| `RemoteConfigService` | `lib/services/remote_config_service.dart` | ❌ absent |
| `AchievementEngine` | `lib/services/achievement_engine.dart` | ❌ absent |
| `ConsentService`, `PurchasesService` | `lib/services/` | ❌ absent |
| `HintSource` enum | anywhere | ❌ absent |
| `LevelNotFoundException` | `lib/engine/level_loader.dart` | ❌ absent |
| `SettingsScreen`, `LevelPickerScreen`, `TrophiesScreen`, `LibraryCompleteScreen` | `lib/screens/` | ❌ absent |
| `GameState.pendingScore` | `lib/models/game_state.dart` | ❌ absent (has `score` instead, per v1.0) |
| `GameState.revealedTileIds` | same | ❌ absent |

**Conclusion:** v2 is a clean slate for contracts. Phase 1 must introduce the full v1.1 service layer (ad/audio/rewards/settings scaffold) without assuming any pre-existing infrastructure.

---

## 0.2 Test baseline

```
flutter test
```

10 tests, all green:

- `GameEngine letterCount counts correctly`
- `GameEngine canFormWord - valid`
- `GameEngine canFormWord - invalid`
- `GameEngine validateWord - found`
- `GameEngine validateWord - already found`
- `GameEngine validateWord - bonus`
- `GameEngine validateWord - invalid word not in targets`
- `GameEngine scoreWord scoring`
- `GameEngine isLevelComplete`
- `GameEngine shuffleList returns all elements`

All tests live in `test/widget_test.dart` (the filename is a misnomer — they're all unit tests of the engine).

**Coverage gaps:**
- No `LevelLoader` tests (Phase 3 Task 1 will add them).
- No `GameProvider` tests (Phase 2 will add them).
- No `SettingsProvider` tests (Phase 1 will add them).
- No widget tests.

**Implication:** the existing suite is a sanity floor, not a safety net. Phases must assume that anything not covered by a new test introduced in-phase could regress silently. Err toward more tests, not fewer.

---

## 0.3 Analyzer baseline

```
flutter analyze
```

**Result:** `No issues found! (ran in 72.1s)`.

No pre-flight cleanup required before Phase 1.

**Dependency drift note:** `flutter pub get` reported six packages with newer versions blocked by constraints:
- `google_fonts` 6.3.3 → 8.0.2
- `meta` 1.17.0 → 1.18.2
- `path_provider_android` 2.2.23 → 2.3.1
- `test_api` 0.7.10 → 0.7.11
- `vector_math` 2.2.0 → 2.3.0
- `vm_service` 15.0.2 → 15.1.0

None are blocking. Revisit during Phase 1 when `pubspec.yaml` is being edited anyway.

---

## 0.4 Code-surface read — key files the plans will modify

### `lib/models/game_state.dart` (143 lines)

**What v2 has that the plans don't anticipate:**

- `enum LevelDifficulty { beginner, easy, medium, hard, expert }` — 5-bucket string enum. Contracts file expected `int? difficulty` (1..5). **Decision needed:** keep the existing enum (and update V1_1_CONTRACTS.md to match) or rewrite to `int? difficulty`. Recommend **keep enum** — more type-safe, already wired through strings. Note that this is also misaligned with DECISIONS.md D16's P1–P10 profile system; the enum reflects a pre-D16 5-profile mapping.
- `TargetWord.revealedIndices: Set<int>` — per-word set of revealed letter positions, already supporting the hint-reveal UX (commit `17e8bdc`).
- `GameLevel.tooCommon: List<String>` + `WordValidationResult.tooCommon` — tooCommon routing is already implemented.
- `GameLevel.levelNumber: int` — per-difficulty-bucket index (1-based), separate from the global level position. Plans assumed a single global level ID.
- `GameState.hintedLetterCounts: Map<String, int>` — tracks which letters have been revealed by hints (per-level).

**What v2 still has from v1.0 (Phase 2 expects to remove):**

- `GameState.score: int` — session score. Phase 2 plan removes this in favour of `pendingScore` + `RewardsProvider.lifetimeScore`.
- `GameState.hintsRemaining: int` (defaults to 3, per-level quota). Phase 2 plan removes this in favour of `RewardsProvider.canUseHint`.

### `lib/providers/game_provider.dart` (260 lines)

- `useHint()` (lines 192–238) implements **per-letter reveal** — picks the letter with most occurrences across unfound required words and reveals every occurrence in every unfound word in one tap. One hint = one letter across the board. This is the Kat/hint-reveal redesign the plans know about but don't describe in implementation-ready detail.
- `nextLevel()` (lines 240–251) carries `score` and `hintsRemaining` forward between levels. Phase 2 rewrites this to bank `pendingScore` into `RewardsProvider.lifetimeScore` via `onLevelComplete()` and reset session state.
- `startGame()` (lines 22–27) accepts `levelNumber` — good, already supports level picker entry (Phase 3).
- No `libraryComplete` flag; `LevelLoader.generateLevel` still does `(levelNumber - 1) % defs.length` silent wrap. **D17 fix is not yet implemented.**

### `lib/providers/settings_provider.dart` (27 lines)

- Persists only `LanguageMode` under the plain key `language_mode` (not `settings.languageMode` as the contracts file requires).
- No `muted` field yet (Phase 1 adds this).
- No `hasChosenLanguage` getter; `_languageMode` always defaults to `LanguageMode.russian` on first launch. Phase 1 re-entry flow will need a nullable variant (previously flagged in my agent-notification notes).

### `lib/engine/level_loader.dart` (85 lines)

- `generateLevel()` reads `def['difficulty']` as a string and maps to `LevelDifficulty` enum. Generator-produced JSON writes `"difficulty": "easy"`, etc.
- `def['levelNumber']` is read and used for the on-screen stamp — this is the per-difficulty index, not the global level index. `GameProvider._currentLevelIndex` is the global one.
- **Silent modulo wrap at line 46:** `defs[(levelNumber - 1) % defs.length]`. Phase 3 Task 1 (D17) replaces this with a `LevelNotFoundException` throw.
- No `LevelValidator` CLI referenced (Phase 7 tooling lives separately under `tools/level_generator/`, not in `lib/`).

### `lib/engine/game_engine.dart` (73 lines)

- `validateWord` handles `tooCommon` before checking targets — correct.
- `scoreWord` uses the v1.0 formula: `length * 10 + tieredBonus`. Phase 2 replaces this with the pending-bank formula from GDD §4.4.
- No bonus-word-counter logic here — Phase 2 adds it in `GameProvider` calling `RewardsProvider.incrementBonusCounter()`.

### `lib/widgets/word_slot_item.dart` (75 lines)

- Already renders `revealedIndices` — hinted letters appear in amber against amber underline; unfound letters show empty slot with cream underline; found letters show navy. Flutter-animate scale-bump on `justFound`.
- Phase 2 only needs to wire the reveal events to `AudioService.playHintReveal` and `RewardsProvider.consumeHint`. The visual is done.

### `lib/widgets/word_slots.dart` (91 lines)

- Bonus words are hidden until found (commit `2826af6`). This is a silent UX change from v1.0 that the GDD needs to acknowledge post-Phase-2.

### `lib/screens/game_screen.dart` (412 lines) and `lib/screens/home_screen.dart` (221 lines)

- `game_screen.dart`: top bar with stamp + difficulty label (`state.level.difficulty` → `StringsRu.difficultyLabel`). Phase 3 will add a "back to level picker" button here.
- `home_screen.dart`: single-screen with RU+EN play buttons, decorative tiles, rules button. Phase 1 re-entry work will split this into `_LanguagePicker` (first-run) and `_HomeMain` (returning-user with progress state).

### `lib/main.dart` (32 lines)

- Loads `SettingsProvider` with `await settings.load()` **before** `runApp`. Phase 1 must extend this bootstrap with `RewardsProvider.load()`, `AdGateway.initialize()` (Noop in Phase 1), `AudioService.initialize()` (no-op skeleton), all before `runApp`.
- Provider tree is flat (`settings`, `game`). Phase 1 rewrites to `MultiProvider` with the full v1.1 order: `AdGateway` (plain `Provider`), `SettingsProvider`, `RewardsProvider`, `GameProvider` (ChangeNotifierProxyProvider so it can read `RewardsProvider`).

---

## Level data snapshot

| Language | Level count | Difficulty distribution |
|---|---|---|
| Russian | 23 | 4 beginner / 9 easy / 6 medium / 1 hard / 3 expert |
| English | 20 | 5 beginner / 7 easy / 5 medium / 3 hard / 0 expert |

Both languages are well below the v1.1 launch bar (50 per language; 100 ideal). The generator and calibration tools exist under `tools/level_generator/` to author more. Phase 7 (rewritten per Stage 1) is the place to execute that authoring push.

---

## Plan-by-plan verdict

| Phase | Plan file | Verdict | Action in Stage 1 |
|---|---|---|---|
| 1 | `phase-1-foundations.md` | **As-written is executable.** All contracts absent, so introducing them is a clean add. Minor: adjust provider persistence keys to match v2's existing `language_mode` (not `settings.languageMode`) unless we migrate. | **No rewrite.** Add a one-paragraph preamble noting v2 baseline. |
| 2 | `phase-2-scoring-hints.md` | **Needs rewrite.** Assumes v1.0 first-letter auto-select hint; v2 has letter-reveal. Remove the safe-letter-algorithm task; rewrite the hint task as "wire reveal UX to `HintSource` + bonus accumulator". Pending-bank scoring and bonus-word accumulator remain as-is. | **Full task-list edit.** |
| 3 | `phase-3-progression.md` | **As-written is executable.** D17 fix to `LevelLoader` is still needed (v2 still has silent wrap). Achievement engine, level picker, library-complete all still greenfield. | **No rewrite.** |
| 4 | `phase-4-audio.md` | **As-written is executable.** No audio code on v2. | **No rewrite.** |
| 5 | `phase-5-monetisation.md` | **As-written is executable.** No ad/IAP code on v2. | **No rewrite.** Verify Android signing config (`1c46903`) is compatible with AdMob app-id injection. |
| 6 | `phase-6-analytics.md` | **As-written is executable.** No Firebase integration on v2. | **No rewrite.** |
| 7 | `phase-7-content.md` | **Needs rewrite.** Assumes manual authoring; v2 has full generator + calibration pipeline under `tools/level_generator/`. Rewrite tasks as "run calibration, curate output, verify 50-level launch bar, tag difficulty, CI hook". Delete the `int? difficulty` task (v2 already has `LevelDifficulty` enum). Also reconcile enum-vs-P1–P10 mismatch with DECISIONS.md D16. | **Full task-list edit.** |
| 8 | `phase-8-accessibility.md` | **As-written is executable.** No accessibility work on v2 yet. | **No rewrite.** |
| 9 | `phase-9-store-readiness.md` | **Light rewrite.** Android signing + launcher icons pre-done by commit `1c46903`. iOS icons, splash, store listings, privacy, data safety, CI workflow, screenshots all still to do. | **Delete two tasks; verify one.** |

---

## Discrepancies to record in DECISIONS.md after Stage 1

When plans are rewritten, new decisions may need recording:

1. **DecisionX:** `LevelDifficulty` enum vs `int 1..5` — which wins for v1.1.
2. **DecisionX:** `LevelDifficulty` 5-bucket enum vs DECISIONS.md D16's P1–P10 profile system — the enum pre-dates D16 and needs expansion or retirement.
3. **DecisionX:** `settings.languageMode` vs existing `language_mode` persistence key — migrate or accept.
4. **DecisionX:** Bonus words hidden until found (commit `2826af6`) — silent UX change that should be ratified.

These are **not** recorded now. They surface during the Phase 1 / Phase 2 / Phase 7 rewrites in Stage 1 and get logged then.

---

## Next step

Proceed to **Stage 1:** rewrite `phase-2-scoring-hints.md`, `phase-7-content.md`, and (lightly) `phase-9-store-readiness.md` against this baseline. Estimated effort: 4–6 hours total. All other phase plans are executable as-written once their dependencies land.

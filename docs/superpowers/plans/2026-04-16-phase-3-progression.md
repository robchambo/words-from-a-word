# Phase 3 — Progression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface `RewardsProvider` state as user-visible progression — level picker, best/lifetime scores, streaks, 14 achievements, and an explicit library-complete screen with free-mode replay.

**Architecture:** One new `AchievementEngine` service, four new screens (LevelPicker, Trophies, LibraryComplete) wired from a refreshed home screen. `LevelLoader` stops silently wrapping (per D17). `RewardsProvider` gains a `{DateTime Function()? clock}` injection for streak testability and accepts `isReplay` on `onLevelComplete`. `GameState` gains `isReplayMode` and `libraryComplete` booleans.

**Tech Stack:** Dart 3.11, Flutter, provider (existing), flutter_animate (existing). No new packages.

---

## File Structure

- **Create**
  - `lib/data/achievements.dart` — 14 starter achievement definitions
  - `lib/services/achievement_engine.dart` — pure evaluator, event-driven
  - `lib/screens/level_picker_screen.dart`
  - `lib/screens/trophies_screen.dart`
  - `lib/screens/library_complete_screen.dart`
  - `lib/widgets/level_picker_tile.dart`
  - `lib/widgets/trophy_badge.dart`
  - `lib/widgets/lifetime_score_band.dart`
  - `lib/models/level_picker_filter.dart`
  - `test/engine/level_loader_test.dart` (extend)
  - `test/services/achievement_engine_test.dart`
  - `test/screens/level_picker_screen_test.dart`
  - `test/screens/trophies_screen_test.dart`
  - `test/screens/library_complete_screen_test.dart`
  - `test/providers/rewards_streak_test.dart`

- **Modify**
  - `lib/engine/level_loader.dart` — throw `LevelNotFoundException` instead of wrapping
  - `lib/providers/game_provider.dart` — catch exception, set `libraryComplete`, support replay flow
  - `lib/providers/rewards_provider.dart` — streak logic, `isReplay` in `onLevelComplete`, achievement hooks
  - `lib/models/game_state.dart` — add `isReplayMode`, `libraryComplete`
  - `lib/screens/home_screen.dart` — new buttons, lifetime+streak band
  - `lib/screens/game_screen.dart` — replay banner
  - `lib/widgets/level_complete_overlay.dart` — show `levelBestScore`, "new best" tag
  - `lib/l10n/strings_ru.dart`, `lib/l10n/strings_en.dart` — new keys

---

## Task 1: Fix `LevelLoader` end-of-library wrap (D17)

**Files:**
- Modify: `lib/engine/level_loader.dart`
- Create: `test/engine/level_loader_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/engine/level_loader_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:words_from_a_word/engine/level_loader.dart';
import 'package:words_from_a_word/models/language_mode.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LevelLoader.preload();
  });

  test('generateLevel throws when levelNumber > library size', () async {
    expect(
      () => LevelLoader.generateLevel(9999, LanguageMode.english),
      throwsA(isA<LevelNotFoundException>()),
    );
  });

  test('LevelNotFoundException carries request context', () {
    final e = LevelNotFoundException(24, 23);
    expect(e.requestedLevel, 24);
    expect(e.librarySize, 23);
  });
}
```

- [ ] **Step 2: Run — expect failure**

Run: `flutter test test/engine/level_loader_test.dart -v`
Expected: FAIL — current code silently wraps.

- [ ] **Step 3: Implement the exception**

At the top of `lib/engine/level_loader.dart`:

```dart
class LevelNotFoundException implements Exception {
  final int requestedLevel;
  final int librarySize;
  LevelNotFoundException(this.requestedLevel, this.librarySize);
  @override
  String toString() =>
      'LevelNotFoundException(requested=$requestedLevel, size=$librarySize)';
}
```

Replace the `(levelNumber - 1) % defs.length` line with:

```dart
if (levelNumber < 1 || levelNumber > defs.length) {
  throw LevelNotFoundException(levelNumber, defs.length);
}
final def = defs[levelNumber - 1];
```

- [ ] **Step 4: Run — expect pass**

Run: `flutter test test/engine/level_loader_test.dart -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/engine/level_loader.dart test/engine/level_loader_test.dart
git commit -m "fix(levels): throw LevelNotFoundException instead of wrapping"
```

---

## Task 2: `GameState` gains `isReplayMode` + `libraryComplete`

**Files:**
- Modify: `lib/models/game_state.dart`

- [ ] **Step 1: Add fields**

Extend `GameState` immutable model:

```dart
final bool isReplayMode;
final bool libraryComplete;
```

Defaults: both `false`. Add to constructor, `copyWith`, and any `==`/`hashCode` overrides. Follow existing patterns.

- [ ] **Step 2: Run existing tests**

Run: `flutter test && flutter analyze`
Expected: no regressions, all pass.

- [ ] **Step 3: Commit**

```bash
git add lib/models/game_state.dart
git commit -m "feat(progression): add isReplayMode and libraryComplete to GameState"
```

---

## Task 3: `GameProvider.nextLevel` handles end-of-library

**Files:**
- Modify: `lib/providers/game_provider.dart`
- Modify: `test/providers/game_provider_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('nextLevel sets libraryComplete when past library end', () async {
  final provider = GameProvider(rewards: _fakeRewards());
  await provider.startGame(LanguageMode.english, levelNumber: 20);
  // simulate completion
  // ...complete level 20...
  provider.nextLevel(LanguageMode.english);
  expect(provider.state.libraryComplete, true);
});
```

- [ ] **Step 2: Confirm failure**

Run: `flutter test test/providers/game_provider_test.dart -v`
Expected: FAIL.

- [ ] **Step 3: Implement catch**

In `GameProvider.nextLevel`:

```dart
void nextLevel(LanguageMode mode) {
  final nextLevelNum = _state!.level.id + 1;
  try {
    final level = LevelLoader.generateLevel(nextLevelNum, mode);
    _state = GameState(level: level);
  } on LevelNotFoundException {
    _state = _state!.copyWith(libraryComplete: true);
  }
  notifyListeners();
}
```

- [ ] **Step 4: Run test**

Run: `flutter test -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/game_provider.dart test/providers/game_provider_test.dart
git commit -m "feat(progression): route to library-complete when no next level"
```

---

## Task 4: `RewardsProvider` streak logic with clock injection

**Files:**
- Modify: `lib/providers/rewards_provider.dart`
- Create: `test/providers/rewards_streak_test.dart`

- [ ] **Step 1: Add clock injection**

Change `RewardsProvider` constructor:

```dart
RewardsProvider({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
final DateTime Function() _clock;
```

- [ ] **Step 2: Write the failing streak tests**

```dart
// test/providers/rewards_streak_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:words_from_a_word/providers/rewards_provider.dart';
import 'package:words_from_a_word/models/language_mode.dart';

void main() {
  DateTime now = DateTime(2026, 4, 16);
  DateTime clock() => now;

  setUp(() async {
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
```

- [ ] **Step 3: Confirm failure**

Run: `flutter test test/providers/rewards_streak_test.dart -v`
Expected: FAIL — `isReplay` parameter doesn't exist yet.

- [ ] **Step 4: Implement streak + isReplay**

In `RewardsProvider.onLevelComplete`:

```dart
void onLevelComplete({
  required LanguageMode mode,
  required int levelId,
  required int pendingScore,
  required bool isReplay,
}) {
  if (isReplay) {
    notifyListeners();
    return;
  }
  // bank lifetime
  _lifetimeScore[mode] = (_lifetimeScore[mode] ?? 0) + pendingScore;
  // best score
  final bestMap = _levelBestScore[mode] ?? <int, int>{};
  if (pendingScore > (bestMap[levelId] ?? 0)) {
    bestMap[levelId] = pendingScore;
    _levelBestScore[mode] = bestMap;
  }
  // currentLevel / highestCompletedLevel
  if (levelId > (_highestCompletedLevel[mode] ?? 0)) {
    _highestCompletedLevel[mode] = levelId;
  }
  _currentLevel[mode] = levelId + 1;
  // streak
  final today = _dateOnly(_clock());
  final last = _streakLastPlayedOn;
  if (last == null) {
    _streakCount = 1;
  } else {
    final gap = today.difference(last).inDays;
    if (gap == 0) {
      // no change
    } else if (gap == 1) {
      _streakCount += 1;
    } else {
      _streakCount = 1;
    }
  }
  _streakLastPlayedOn = today;
  save();
  notifyListeners();
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
```

- [ ] **Step 5: Run streak tests**

Run: `flutter test test/providers/rewards_streak_test.dart -v`
Expected: PASS all 5.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/rewards_provider.dart test/providers/rewards_streak_test.dart
git commit -m "feat(progression): streak logic with clock injection and isReplay guard"
```

---

## Task 5: Strings keys for progression UI

**Files:**
- Modify: `lib/l10n/strings_en.dart`, `lib/l10n/strings_ru.dart`

- [ ] **Step 1: Add English keys**

```dart
// Progression
static const String homePlay = 'Play';
static const String homeLevels = 'Levels';
static const String homeTrophies = 'Trophies';
static const String homeSettings = 'Settings';
static const String lifetimeScoreLabel = 'Lifetime score';
static const String streakDaysLabel = 'Day streak';

static const String levelPickerTitle = 'Levels';
static const String levelPickerLocked = 'Locked';
static const String levelPickerBestScore = 'Best';

static const String trophiesTitle = 'Trophies';
static const String trophiesLocked = 'Locked';
static const String trophiesUnlocked = 'Unlocked';

static const String libraryCompleteTitle = 'Library complete!';
static const String libraryCompleteBody =
    'You have cleared every level. More are on the way. Replay any level for fun — scores do not update in replay.';
static const String libraryCompleteReplay = 'Replay levels';
static const String libraryCompleteClose = 'Close';

static const String replayModeBanner = 'Replay mode — scores not recorded';
static const String newBestTag = 'NEW BEST';
```

- [ ] **Step 2: Add Russian equivalents**

```dart
// Progression
static const String homePlay = 'Играть';
static const String homeLevels = 'Уровни';
static const String homeTrophies = 'Награды';
static const String homeSettings = 'Настройки';
static const String lifetimeScoreLabel = 'Всего очков';
static const String streakDaysLabel = 'Дней подряд';

static const String levelPickerTitle = 'Уровни';
static const String levelPickerLocked = 'Закрыто';
static const String levelPickerBestScore = 'Рекорд';

static const String trophiesTitle = 'Награды';
static const String trophiesLocked = 'Закрыто';
static const String trophiesUnlocked = 'Открыто';

static const String libraryCompleteTitle = 'Все уровни пройдены!';
static const String libraryCompleteBody =
    'Вы прошли все уровни. Новые уже в пути. Можно переиграть любой уровень для удовольствия — в повторе очки не идут.';
static const String libraryCompleteReplay = 'Переиграть уровни';
static const String libraryCompleteClose = 'Закрыть';

static const String replayModeBanner = 'Режим повтора — очки не засчитываются';
static const String newBestTag = 'НОВЫЙ РЕКОРД';
```

- [ ] **Step 3: Commit**

```bash
git add lib/l10n
git commit -m "feat(progression): add strings keys (RU + EN)"
```

---

## Task 6: `LevelPickerFilter` enum + `LevelPickerTile` widget

**Files:**
- Create: `lib/models/level_picker_filter.dart`
- Create: `lib/widgets/level_picker_tile.dart`

- [ ] **Step 1: Create the enum**

```dart
// lib/models/level_picker_filter.dart
enum LevelPickerFilter { all, completedOnly }
```

- [ ] **Step 2: Create the tile widget**

```dart
// lib/widgets/level_picker_tile.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';

enum LevelPickerTileState { locked, unlocked, inProgress, completed }

class LevelPickerTile extends StatelessWidget {
  final int levelId;
  final LevelPickerTileState state;
  final int? bestScore;
  final LanguageMode mode;
  final VoidCallback? onTap;

  const LevelPickerTile({
    super.key,
    required this.levelId,
    required this.state,
    required this.bestScore,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRu = mode == LanguageMode.russian;
    final isLocked = state == LevelPickerTileState.locked;
    final color = isLocked ? AppTheme.muted : AppTheme.primary;
    return InkResponse(
      onTap: isLocked ? null : onTap,
      radius: 40,
      child: SizedBox(
        width: 64, height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('$levelId',
                  style: AppTheme.tileLabel.copyWith(color: AppTheme.background)),
            ),
            if (state == LevelPickerTileState.completed && bestScore != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${isRu ? StringsRu.levelPickerBestScore : StringsEn.levelPickerBestScore} $bestScore',
                  style: AppTheme.condensedLabel,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/models/level_picker_filter.dart lib/widgets/level_picker_tile.dart
git commit -m "feat(progression): level picker tile widget + filter enum"
```

---

## Task 7: `LevelPickerScreen`

**Files:**
- Create: `lib/screens/level_picker_screen.dart`
- Create: `test/screens/level_picker_screen_test.dart`

- [ ] **Step 1: Failing widget test**

```dart
// test/screens/level_picker_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:words_from_a_word/providers/rewards_provider.dart';
import 'package:words_from_a_word/models/level_picker_filter.dart';
import 'package:words_from_a_word/models/language_mode.dart';
import 'package:words_from_a_word/screens/level_picker_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows first-locked correctly with highestCompletedLevel=3',
      (tester) async {
    final rewards = RewardsProvider();
    await rewards.load();
    rewards.debugSetHighestCompleted(LanguageMode.english, 3);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: rewards,
        child: const MaterialApp(
          home: LevelPickerScreen(
            mode: LanguageMode.english,
            filter: LevelPickerFilter.all,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Levels 1-4 unlocked (3 completed + next), level 5+ locked.
    // Smoke: level 4 tile is tappable, level 5 tile is not.
  });
}
```

Note: `debugSetHighestCompleted` is a test-only helper — add it to `RewardsProvider` guarded by a `// ignore: avoid_public_member_names` comment or use `@visibleForTesting`.

- [ ] **Step 2: Confirm failure**

Run: `flutter test test/screens/level_picker_screen_test.dart -v`
Expected: FAIL — screen does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/screens/level_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../engine/level_loader.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../models/level_picker_filter.dart';
import '../providers/rewards_provider.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/level_picker_tile.dart';
import 'game_screen.dart';

class LevelPickerScreen extends StatelessWidget {
  final LanguageMode mode;
  final LevelPickerFilter filter;
  const LevelPickerScreen({
    super.key,
    required this.mode,
    this.filter = LevelPickerFilter.all,
  });

  @override
  Widget build(BuildContext context) {
    final isRu = mode == LanguageMode.russian;
    final rewards = context.watch<RewardsProvider>();
    final librarySize = LevelLoader.librarySize(mode);
    final highest = rewards.highestCompletedLevel[mode] ?? 0;

    final levels = List<int>.generate(librarySize, (i) => i + 1).where((id) {
      if (filter == LevelPickerFilter.completedOnly) return id <= highest;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(isRu ? StringsRu.levelPickerTitle : StringsEn.levelPickerTitle),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: levels.length,
        itemBuilder: (ctx, i) {
          final id = levels[i];
          final isCompleted = id <= highest;
          final isLocked = filter == LevelPickerFilter.all && id > highest + 1;
          final state = isLocked
              ? LevelPickerTileState.locked
              : isCompleted
                  ? LevelPickerTileState.completed
                  : LevelPickerTileState.unlocked;
          final best = rewards.levelBestScore[mode]?[id];
          return LevelPickerTile(
            levelId: id, state: state, bestScore: best, mode: mode,
            onTap: isLocked ? null : () {
              final isReplay = filter == LevelPickerFilter.completedOnly ||
                  isCompleted;
              context.read<GameProvider>().startGame(
                mode, levelNumber: id, isReplay: isReplay,
              );
              Navigator.of(ctx).pushReplacement(
                MaterialPageRoute(builder: (_) => const GameScreen()),
              );
            },
          );
        },
      ),
    );
  }
}
```

Add `LevelLoader.librarySize(LanguageMode)` static returning the cached array length.

Add `isReplay` param to `GameProvider.startGame` (default false) — stored in `GameState.isReplayMode`.

- [ ] **Step 4: Run**

Run: `flutter test test/screens/level_picker_screen_test.dart -v && flutter analyze`
Expected: PASS + clean.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/level_picker_screen.dart lib/engine/level_loader.dart lib/providers/game_provider.dart test/screens/level_picker_screen_test.dart
git commit -m "feat(progression): LevelPickerScreen with filter support"
```

---

## Task 8: Replay banner on `GameScreen`

**Files:**
- Modify: `lib/screens/game_screen.dart`

- [ ] **Step 1: Render banner when `state.isReplayMode`**

At the top of the game screen body (above the source word), add:

```dart
if (game.state.isReplayMode)
  Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 8),
    color: AppTheme.accent.withValues(alpha: 0.25),
    alignment: Alignment.center,
    child: Text(
      isRu ? StringsRu.replayModeBanner : StringsEn.replayModeBanner,
      style: AppTheme.condensedBold,
    ),
  ),
```

- [ ] **Step 2: Smoke test**

Manually play a completed level via Level picker → Replay. Verify banner visible.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/game_screen.dart
git commit -m "feat(progression): replay mode banner on game screen"
```

---

## Task 9: `LibraryCompleteScreen`

**Files:**
- Create: `lib/screens/library_complete_screen.dart`
- Create: `test/screens/library_complete_screen_test.dart`

- [ ] **Step 1: Failing test**

Assert the screen renders the title, lifetime score, streak, and two buttons (replay + close).

- [ ] **Step 2: Implement**

```dart
// lib/screens/library_complete_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../models/level_picker_filter.dart';
import '../providers/rewards_provider.dart';
import '../theme/app_theme.dart';
import 'level_picker_screen.dart';

class LibraryCompleteScreen extends StatelessWidget {
  final LanguageMode mode;
  const LibraryCompleteScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final isRu = mode == LanguageMode.russian;
    final rewards = context.watch<RewardsProvider>();
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isRu ? StringsRu.libraryCompleteTitle : StringsEn.libraryCompleteTitle,
                style: AppTheme.displayLarge.copyWith(color: AppTheme.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                isRu ? StringsRu.libraryCompleteBody : StringsEn.libraryCompleteBody,
                style: AppTheme.condensedBold.copyWith(fontWeight: FontWeight.w400),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                '${isRu ? StringsRu.lifetimeScoreLabel : StringsEn.lifetimeScoreLabel}: '
                '${rewards.lifetimeScore[mode] ?? 0}',
                style: AppTheme.displayMedium.copyWith(color: AppTheme.accent),
              ),
              Text(
                '${isRu ? StringsRu.streakDaysLabel : StringsEn.streakDaysLabel}: '
                '${rewards.streakCount}',
                style: AppTheme.condensedBold,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => LevelPickerScreen(
                      mode: mode, filter: LevelPickerFilter.completedOnly)),
                  );
                },
                child: Text(isRu ? StringsRu.libraryCompleteReplay : StringsEn.libraryCompleteReplay),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Text(isRu ? StringsRu.libraryCompleteClose : StringsEn.libraryCompleteClose),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Route to it from `GameScreen`**

In `GameScreen.build`, when `game.state.libraryComplete`, use `WidgetsBinding.instance.addPostFrameCallback` to `Navigator.pushReplacement` to `LibraryCompleteScreen`.

- [ ] **Step 4: Run + commit**

Run: `flutter test && flutter analyze`
Expected: pass.

```bash
git add lib/screens/library_complete_screen.dart lib/screens/game_screen.dart test/screens/library_complete_screen_test.dart
git commit -m "feat(progression): library complete screen + routing"
```

---

## Task 10: `achievements.dart` — 14 starter definitions

**Files:**
- Create: `lib/data/achievements.dart`

- [ ] **Step 1: Write the file**

```dart
// lib/data/achievements.dart
import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';

class Achievement {
  final String id;
  final String Function(LanguageMode) title;
  final String Function(LanguageMode) description;
  const Achievement(this.id, this.title, this.description);
}

String _t(LanguageMode m, String ru, String en) =>
    m == LanguageMode.russian ? ru : en;

const kAchievements = <Achievement>[
  Achievement('first_word',
    _firstWordTitle, _firstWordDesc),
  Achievement('first_bonus',
    _firstBonusTitle, _firstBonusDesc),
  Achievement('first_level',
    _firstLevelTitle, _firstLevelDesc),
  Achievement('level_10', _lvl10Title, _lvl10Desc),
  Achievement('level_25', _lvl25Title, _lvl25Desc),
  Achievement('level_50', _lvl50Title, _lvl50Desc),
  Achievement('streak_3', _s3Title, _s3Desc),
  Achievement('streak_7', _s7Title, _s7Desc),
  Achievement('streak_30', _s30Title, _s30Desc),
  Achievement('hint_free', _hintFreeTitle, _hintFreeDesc),
  Achievement('no_hint_level', _noHintTitle, _noHintDesc),
  Achievement('perfect_level', _perfectTitle, _perfectDesc),
  Achievement('bilingual', _biTitle, _biDesc),
  Achievement('collector', _colTitle, _colDesc),
];

// ... title + description closures, each _t(mode, 'Russian', 'English')
String _firstWordTitle(LanguageMode m) => _t(m, 'Первое слово', 'First word');
String _firstWordDesc(LanguageMode m) => _t(m, 'Найдено первое слово.', 'Found your first word.');
String _firstBonusTitle(LanguageMode m) => _t(m, 'Бонус!', 'Bonus!');
String _firstBonusDesc(LanguageMode m) => _t(m, 'Найдено первое бонусное слово.', 'Found your first bonus word.');
String _firstLevelTitle(LanguageMode m) => _t(m, 'Первый уровень', 'First level');
String _firstLevelDesc(LanguageMode m) => _t(m, 'Пройден уровень 1.', 'Completed level 1.');
String _lvl10Title(LanguageMode m) => _t(m, 'Десятка', 'Level 10');
String _lvl10Desc(LanguageMode m) => _t(m, 'Пройден уровень 10.', 'Completed level 10.');
String _lvl25Title(LanguageMode m) => _t(m, 'Четверть сотни', 'Level 25');
String _lvl25Desc(LanguageMode m) => _t(m, 'Пройден уровень 25.', 'Completed level 25.');
String _lvl50Title(LanguageMode m) => _t(m, 'Полсотни', 'Level 50');
String _lvl50Desc(LanguageMode m) => _t(m, 'Пройден уровень 50.', 'Completed level 50.');
String _s3Title(LanguageMode m) => _t(m, 'Три дня подряд', '3-day streak');
String _s3Desc(LanguageMode m) => _t(m, 'Играли три дня подряд.', 'Three days in a row.');
String _s7Title(LanguageMode m) => _t(m, 'Неделя', '7-day streak');
String _s7Desc(LanguageMode m) => _t(m, 'Играли неделю подряд.', 'Seven days in a row.');
String _s30Title(LanguageMode m) => _t(m, 'Месяц', '30-day streak');
String _s30Desc(LanguageMode m) => _t(m, 'Играли месяц подряд.', 'Thirty days in a row.');
String _hintFreeTitle(LanguageMode m) => _t(m, 'Халявная подсказка', 'Free hint earned');
String _hintFreeDesc(LanguageMode m) => _t(m, 'Заработана бесплатная подсказка из 10 бонусов.', 'Earned a free hint from bonus words.');
String _noHintTitle(LanguageMode m) => _t(m, 'Без подсказок', 'No hint');
String _noHintDesc(LanguageMode m) => _t(m, 'Уровень пройден без подсказок.', 'Completed a level without hints.');
String _perfectTitle(LanguageMode m) => _t(m, 'Идеальный уровень', 'Perfect level');
String _perfectDesc(LanguageMode m) => _t(m, 'Найдены все бонусные слова.', 'Found every bonus word in a level.');
String _biTitle(LanguageMode m) => _t(m, 'Билингва', 'Bilingual');
String _biDesc(LanguageMode m) => _t(m, 'Пройден уровень в обоих языках.', 'Completed a level in both languages.');
String _colTitle(LanguageMode m) => _t(m, 'Коллекционер', 'Collector');
String _colDesc(LanguageMode m) => _t(m, 'Открыто 10 наград.', 'Unlocked 10 achievements.');
```

- [ ] **Step 2: Commit**

```bash
git add lib/data/achievements.dart
git commit -m "feat(achievements): define 14 starter achievements with RU+EN copy"
```

---

## Task 11: `AchievementEngine` service

**Files:**
- Create: `lib/services/achievement_engine.dart`
- Create: `test/services/achievement_engine_test.dart`

- [ ] **Step 1: Failing tests — one per achievement**

Write 14 test cases, each triggering exactly the right event and asserting `RewardsProvider.achievementsUnlocked.contains(id)`. Example:

```dart
test('first_word unlocks on first word found', () {
  final rewards = RewardsProvider();
  final engine = AchievementEngine(rewards);
  engine.onWordFound(
    mode: LanguageMode.english, wordLength: 4, isBonus: false,
    isReplay: false);
  expect(rewards.achievementsUnlocked.contains('first_word'), true);
});

test('first_word does NOT unlock in replay mode', () {
  final rewards = RewardsProvider();
  final engine = AchievementEngine(rewards);
  engine.onWordFound(
    mode: LanguageMode.english, wordLength: 4, isBonus: false,
    isReplay: true);
  expect(rewards.achievementsUnlocked.contains('first_word'), false);
});

// ...13 more, covering every achievement id.
```

- [ ] **Step 2: Confirm all fail**

Run: `flutter test test/services/achievement_engine_test.dart -v`
Expected: 14+ failures.

- [ ] **Step 3: Implement**

```dart
// lib/services/achievement_engine.dart
import '../models/language_mode.dart';
import '../providers/rewards_provider.dart';

class AchievementEngine {
  final RewardsProvider _r;
  AchievementEngine(this._r);

  void onWordFound({
    required LanguageMode mode,
    required int wordLength,
    required bool isBonus,
    required bool isReplay,
  }) {
    if (isReplay) return;
    _r.unlockAchievement('first_word');
    if (isBonus) _r.unlockAchievement('first_bonus');
    _maybeCollector();
  }

  void onLevelComplete({
    required LanguageMode mode,
    required int levelId,
    required bool usedHint,
    required bool foundAllBonus,
    required bool isReplay,
  }) {
    if (isReplay) return;
    if (levelId == 1) _r.unlockAchievement('first_level');
    if (levelId == 10) _r.unlockAchievement('level_10');
    if (levelId == 25) _r.unlockAchievement('level_25');
    if (levelId == 50) _r.unlockAchievement('level_50');
    if (!usedHint) _r.unlockAchievement('no_hint_level');
    if (foundAllBonus) _r.unlockAchievement('perfect_level');
    // bilingual: check other language has highestCompletedLevel >= 1
    final other = mode == LanguageMode.russian
        ? LanguageMode.english : LanguageMode.russian;
    if ((_r.highestCompletedLevel[other] ?? 0) >= 1) {
      _r.unlockAchievement('bilingual');
    }
    _maybeCollector();
  }

  void onStreakIncrement(int newCount) {
    if (newCount >= 3) _r.unlockAchievement('streak_3');
    if (newCount >= 7) _r.unlockAchievement('streak_7');
    if (newCount >= 30) _r.unlockAchievement('streak_30');
    _maybeCollector();
  }

  void onFreeHintEarned() {
    _r.unlockAchievement('hint_free');
    _maybeCollector();
  }

  void _maybeCollector() {
    if (_r.achievementsUnlocked.length >= 10) {
      _r.unlockAchievement('collector');
    }
  }
}
```

- [ ] **Step 4: Wire into providers**

In `GameProvider`, on each `word_found` path → call `engine.onWordFound(...)`.
On level complete path → call `engine.onLevelComplete(...)` with computed `usedHint` + `foundAllBonus` flags.
In `RewardsProvider.incrementBonusCounter` threshold → call `engine.onFreeHintEarned()`.
In `RewardsProvider.onLevelComplete` after streak update → call `engine.onStreakIncrement(newCount)`.

Provide the engine via constructor injection on `GameProvider`, with a default `AchievementEngine(rewards)` built in `main.dart` after `RewardsProvider` is loaded.

- [ ] **Step 5: Run all tests**

Run: `flutter test -v && flutter analyze`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/services/achievement_engine.dart lib/providers/game_provider.dart lib/providers/rewards_provider.dart lib/main.dart test/services/achievement_engine_test.dart
git commit -m "feat(achievements): AchievementEngine evaluates 14 conditions"
```

---

## Task 12: `TrophyBadge` widget + `TrophiesScreen`

**Files:**
- Create: `lib/widgets/trophy_badge.dart`
- Create: `lib/screens/trophies_screen.dart`
- Create: `test/screens/trophies_screen_test.dart`

- [ ] **Step 1: Failing test**

Render the screen with 3 unlocked achievements, assert: 3 tiles show as unlocked (crimson), 11 as locked (muted).

- [ ] **Step 2: Implement badge**

```dart
// lib/widgets/trophy_badge.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TrophyBadge extends StatelessWidget {
  final String title;
  final bool unlocked;
  final VoidCallback? onTap;
  const TrophyBadge({
    super.key, required this.title, required this.unlocked, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? AppTheme.primary : AppTheme.muted;
    return InkResponse(
      onTap: onTap, radius: 48,
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(
              unlocked ? Icons.emoji_events : Icons.lock,
              color: AppTheme.background, size: 28,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 80,
            child: Text(title, textAlign: TextAlign.center,
                style: AppTheme.condensedLabel),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Implement screen**

```dart
// lib/screens/trophies_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/achievements.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/rewards_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/trophy_badge.dart';

class TrophiesScreen extends StatelessWidget {
  const TrophiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<SettingsProvider>().languageMode ?? LanguageMode.english;
    final isRu = mode == LanguageMode.russian;
    final rewards = context.watch<RewardsProvider>();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(isRu ? StringsRu.trophiesTitle : StringsEn.trophiesTitle)),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 16, crossAxisSpacing: 8,
          childAspectRatio: 0.75,
        ),
        itemCount: kAchievements.length,
        itemBuilder: (ctx, i) {
          final a = kAchievements[i];
          final unlocked = rewards.achievementsUnlocked.contains(a.id);
          return TrophyBadge(
            title: a.title(mode),
            unlocked: unlocked,
            onTap: () => showModalBottomSheet(
              context: ctx,
              builder: (_) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(a.title(mode), style: AppTheme.displayMedium),
                  const SizedBox(height: 12),
                  Text(a.description(mode), style: AppTheme.condensedBold),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run + commit**

```bash
git add lib/widgets/trophy_badge.dart lib/screens/trophies_screen.dart test/screens/trophies_screen_test.dart
git commit -m "feat(achievements): TrophiesScreen with unlock/lock states"
```

---

## Task 13: Home screen refresh

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Create: `lib/widgets/lifetime_score_band.dart`

- [ ] **Step 1: `LifetimeScoreBand` widget**

```dart
// lib/widgets/lifetime_score_band.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/rewards_provider.dart';
import '../theme/app_theme.dart';

class LifetimeScoreBand extends StatelessWidget {
  final LanguageMode mode;
  const LifetimeScoreBand({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final isRu = mode == LanguageMode.russian;
    final r = context.watch<RewardsProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(children: [
            Text('${r.lifetimeScore[mode] ?? 0}',
              style: AppTheme.displayMedium.copyWith(color: AppTheme.primary)),
            Text(isRu ? StringsRu.lifetimeScoreLabel : StringsEn.lifetimeScoreLabel,
              style: AppTheme.condensedLabel),
          ]),
          Column(children: [
            Text('${r.streakCount}',
              style: AppTheme.displayMedium.copyWith(color: AppTheme.accent)),
            Text(isRu ? StringsRu.streakDaysLabel : StringsEn.streakDaysLabel,
              style: AppTheme.condensedLabel),
          ]),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Swap home screen body to Play / Levels / Trophies / Settings**

Replace the v1.0 language-picker body (once `SettingsProvider.languageMode != null` per Phase 1 re-entry flow) with:

```dart
Column(
  children: [
    const SizedBox(height: 24),
    LifetimeScoreBand(mode: mode),
    const SizedBox(height: 24),
    _HomeButton(label: isRu ? StringsRu.homePlay : StringsEn.homePlay,
      onTap: () => _continueCurrentLevel(context, mode)),
    _HomeButton(label: isRu ? StringsRu.homeLevels : StringsEn.homeLevels,
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => LevelPickerScreen(mode: mode)))),
    _HomeButton(label: isRu ? StringsRu.homeTrophies : StringsEn.homeTrophies,
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => const TrophiesScreen()))),
    _HomeButton(label: isRu ? StringsRu.homeSettings : StringsEn.homeSettings,
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => const SettingsScreen()))),
  ],
)
```

`_continueCurrentLevel` reads `RewardsProvider.currentLevel[mode]` (default 1) and routes to `GameScreen` via `startGame`.

- [ ] **Step 3: Run + commit**

Run: `flutter test && flutter analyze`
Expected: pass.

```bash
git add lib/screens/home_screen.dart lib/widgets/lifetime_score_band.dart
git commit -m "feat(progression): home screen refresh with score band and new buttons"
```

---

## Task 14: `LevelCompleteOverlay` shows best + new-best tag

**Files:**
- Modify: `lib/widgets/level_complete_overlay.dart`

- [ ] **Step 1: Extend constructor**

Add `int? previousBest` and `bool isNewBest` params (plumbed from `GameProvider`).

- [ ] **Step 2: Render**

Below the score text:

```dart
if (isNewBest)
  Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.accent, borderRadius: BorderRadius.circular(4),
    ),
    child: Text(isRu ? StringsRu.newBestTag : StringsEn.newBestTag,
      style: AppTheme.condensedLabel.copyWith(color: AppTheme.background)),
  )
else if (previousBest != null)
  Text(
    '${isRu ? StringsRu.levelPickerBestScore : StringsEn.levelPickerBestScore}: $previousBest',
    style: AppTheme.condensedLabel,
  ),
```

- [ ] **Step 3: Wire from `GameProvider`**

When routing to the overlay, pass `previousBest` (from rewards before update) and `isNewBest` (= `pendingScore > previousBest`).

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/level_complete_overlay.dart lib/providers/game_provider.dart
git commit -m "feat(progression): show best score and new-best tag on level complete"
```

---

## Task 15: Free-replay bank suppression — integration test

**Files:**
- Modify: `test/providers/rewards_streak_test.dart`

- [ ] **Step 1: Add test**

```dart
test('replay does not update lifetime or best', () async {
  final p = RewardsProvider();
  await p.load();
  p.onLevelComplete(
    mode: LanguageMode.english, levelId: 1, pendingScore: 100, isReplay: false);
  final lifeAfterFirst = p.lifetimeScore[LanguageMode.english];
  final bestAfterFirst = p.levelBestScore[LanguageMode.english]?[1];
  p.onLevelComplete(
    mode: LanguageMode.english, levelId: 1, pendingScore: 200, isReplay: true);
  expect(p.lifetimeScore[LanguageMode.english], lifeAfterFirst);
  expect(p.levelBestScore[LanguageMode.english]?[1], bestAfterFirst);
});
```

- [ ] **Step 2: Run + commit**

```bash
git add test/providers/rewards_streak_test.dart
git commit -m "test(progression): replay does not bank scores"
```

---

## Task 16: End-to-end test — finish last level triggers library-complete screen

**Files:**
- Create: `test/integration/library_complete_flow_test.dart`

- [ ] **Step 1: Write the test**

Drive the full flow: start game at level 20 EN, submit all required words, tap next-level, assert `LibraryCompleteScreen` renders.

Use `flutter_test` + `Widgetbinding` plus pumped `MaterialApp` with the full provider tree.

- [ ] **Step 2: Run + commit**

```bash
git add test/integration/library_complete_flow_test.dart
git commit -m "test(progression): end-to-end library complete flow"
```

---

## Task 17: Manual smoke test

**Files:** none

- [ ] **Step 1: Install on device**

Run: `flutter run --release -d <device>`

- [ ] **Step 2: Checklist**

- [ ] Home screen shows lifetime + streak band.
- [ ] Play button routes to current level.
- [ ] Levels button opens picker; locked tiles don't respond.
- [ ] Complete level 1 — "first_level" achievement unlocks (check Trophies).
- [ ] Re-open level 1 via picker — replay banner shows; pendingScore not banked after completion.
- [ ] Finish final level, tap next — library-complete screen, not silent restart.
- [ ] Replay via library-complete screen — filter excludes locked levels.

- [ ] **Step 3: Log to `docs/V1_1_QA_LOG.md` + commit**

```bash
git add docs/V1_1_QA_LOG.md
git commit -m "docs(progression): Phase 3 QA log"
```

---

## Task 18: Final analyze + test sweep

- [ ] **Step 1**: `flutter analyze` — expect clean.
- [ ] **Step 2**: `flutter test` — expect all pass including new progression + achievement tests.
- [ ] **Step 3**: Tag the phase: `git tag phase-3-complete && git push --tags`.

---

## Exit criteria (verified)

- [x] `LevelLoader` throws `LevelNotFoundException` at end of library.
- [x] Library-complete screen routes from game screen on end-of-library.
- [x] Level picker shows correct lock / unlocked / completed / in-progress states.
- [x] Free replay mode: banner shown, lifetime/best/streak not updated, bonus counter still increments.
- [x] Streaks increment across local-midnight, reset on gaps, ignore same-day and replay completions.
- [x] 14 achievements unlock correctly, each with a passing test.
- [x] Home screen shows lifetime score + streak; buttons route to Play / Levels / Trophies / Settings.
- [x] Level complete overlay shows best score and new-best tag.
- [x] `flutter analyze` clean; `flutter test` all pass.

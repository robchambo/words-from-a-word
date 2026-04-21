# Phase 2 — Scoring & Hint Economy Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace v1.0 scoring + hint mechanics with the v1.1 economy from GDD §4.4 and §4.5 — pending-and-bank scoring, flat 15-pt bonus words, safe-letter hints, free-hint slot, bonus-word accumulator.

**Architecture:** `GameState` drops `score` + `hintsRemaining` and adds `pendingScore`, `revealedTileIds`, and a `revealedPositions: Map<String, Set<int>>` (keyed by target word, value = set of revealed letter indices). `GameEngine` gains `pickSafeHintLetter()` — a pure function with seeded RNG. `GameProvider` reads `RewardsProvider` for hint availability and calls `onLevelComplete` to bank. Two new widgets: `ProgressStrip` (top-of-game bonus counter + banked hints), `FreeHintEarnedOverlay` (celebratory popup driven by a `ValueNotifier<int>` tick source on `RewardsProvider`).

**Tech Stack:** Dart 3.11, Flutter, existing provider + flutter_animate. No new packages.

---

## File Structure

- **Create**
  - `lib/widgets/progress_strip.dart`
  - `lib/widgets/free_hint_earned_overlay.dart`
  - `test/engine/safe_hint_test.dart`
  - `test/providers/pending_score_test.dart`
  - `test/providers/free_hint_refill_test.dart`
  - `test/widgets/word_slot_item_reveal_test.dart`

- **Modify**
  - `lib/models/game_state.dart` — drop `score`, `hintsRemaining`; add new fields
  - `lib/engine/game_engine.dart` — `scoreWord` takes `{required bool isBonus}`; add `pickSafeHintLetter`
  - `lib/providers/game_provider.dart` — new hint wiring, bank-on-complete, rewarded-ad prompt flag
  - `lib/providers/rewards_provider.dart` — add `freeHintEarnedTicks: ValueNotifier<int>`, `nowProvider` injection
  - `lib/widgets/word_slot_item.dart` — underline treatment for revealed positions
  - `lib/widgets/rules_modal.dart` (untouched — copy change is in strings)
  - `lib/screens/game_screen.dart` — mount `ProgressStrip` + `FreeHintEarnedOverlay`
  - `lib/l10n/strings_en.dart`, `lib/l10n/strings_ru.dart` — rewritten `rulesHint` + `rulesScore`; new keys
  - `lib/main.dart` — `ChangeNotifierProxyProvider<RewardsProvider, GameProvider>`

---

## Task 1: `GameEngine.scoreWord` takes `isBonus` and returns flat 15 for bonus

**Files:**
- Modify: `lib/engine/game_engine.dart`
- Modify: `test/engine/game_engine_test.dart` (create if needed)

- [ ] **Step 1: Failing tests**

```dart
test('scoreWord regular: length × 10 + length-bonus', () {
  expect(GameEngine.scoreWord('cat', isBonus: false), 30);        // 3×10 + 0
  expect(GameEngine.scoreWord('berry', isBonus: false), 70);      // 5×10 + 20
  expect(GameEngine.scoreWord('strawberry', isBonus: false), 130); // 10×10 + 30
});

test('scoreWord bonus returns flat 15 regardless of length', () {
  expect(GameEngine.scoreWord('cat', isBonus: true), 15);
  expect(GameEngine.scoreWord('strawberry', isBonus: true), 15);
});
```

- [ ] **Step 2: Confirm failure**

Run: `flutter test test/engine/game_engine_test.dart -v`
Expected: FAIL — signature mismatch.

- [ ] **Step 3: Implement**

In `lib/engine/game_engine.dart`:

```dart
static const int _bonusWordFlatScore = 15; // TODO(phase-6): read from RemoteConfigService.bonusWordFlatScore

static int scoreWord(String word, {required bool isBonus}) {
  if (isBonus) return _bonusWordFlatScore;
  final n = word.length;
  int lengthBonus;
  if (n >= 6) lengthBonus = 30;
  else if (n == 5) lengthBonus = 20;
  else if (n == 4) lengthBonus = 10;
  else lengthBonus = 0;
  return n * 10 + lengthBonus;
}
```

Update every existing call site to pass `isBonus:` explicitly.

- [ ] **Step 4: Run + commit**

```bash
flutter test && flutter analyze
git add lib/engine/game_engine.dart test/engine/game_engine_test.dart
git commit -m "feat(scoring): scoreWord takes isBonus flag; bonus words flat 15"
```

---

## Task 2: `GameState` reshape

**Files:**
- Modify: `lib/models/game_state.dart`

- [ ] **Step 1: Drop `score` and `hintsRemaining`; add new fields**

```dart
class GameState {
  final GameLevel level;
  final List<String> selectedTileIds;
  final String currentInput;
  final List<String> foundWords;
  final int pendingScore;                  // NEW (replaces `score`)
  final Set<String> revealedTileIds;       // NEW — tile IDs revealed by hint
  final Map<String, Set<int>> revealedPositions; // NEW — key: target word, value: revealed letter indices
  final bool pendingRewardedAdPrompt;      // NEW — GameProvider sets true when hint exhausted
  final bool isShaking;
  final String? lastFoundWord;
  final bool isLevelComplete;
  final bool isReplayMode;                 // Phase 3 adds this — include now for forward-compat
  final bool libraryComplete;              // Phase 3 adds this
  // ...

  const GameState({
    required this.level,
    this.selectedTileIds = const [],
    this.currentInput = '',
    this.foundWords = const [],
    this.pendingScore = 0,
    this.revealedTileIds = const {},
    this.revealedPositions = const {},
    this.pendingRewardedAdPrompt = false,
    this.isShaking = false,
    this.lastFoundWord,
    this.isLevelComplete = false,
    this.isReplayMode = false,
    this.libraryComplete = false,
  });

  GameState copyWith({ /* every field nullable in copyWith */ });
}
```

Remove `score` and `hintsRemaining` everywhere. Update `copyWith` and `clearLastFoundWord` logic.

- [ ] **Step 2: Adjust compilation fallout**

Every `state.score` → `state.pendingScore`. Every `state.hintsRemaining` → delete (logic will move to `RewardsProvider.canUseHint` in Task 5).

- [ ] **Step 3: Run**

Run: `flutter analyze` — expect errors in `GameProvider` and widgets; they'll be fixed in Tasks 3–5.

- [ ] **Step 4: Commit (with compilation breakage noted in commit msg — this is a staging commit)**

Actually: wait to commit until Task 3 compiles. Do not commit broken state.

---

## Task 3: `GameProvider` temporary rewiring

**Files:**
- Modify: `lib/providers/game_provider.dart`

- [ ] **Step 1: Swap `score` references to `pendingScore`**

In `submitWord`, when a word is found:

```dart
final points = GameEngine.scoreWord(word, isBonus: foundTarget.isBonus);
_state = s.copyWith(
  pendingScore: s.pendingScore + points,
  // ... other fields
);
```

`foundTarget` is the `TargetWord` matched from `s.level.targetWords`. Compute it before the points call.

- [ ] **Step 2: Remove `hintsRemaining` logic**

Delete the `hintsRemaining` field references. Stub `useHint` for now:

```dart
void useHint() {
  // Real impl lands in Task 5 once RewardsProvider is wired.
}
```

- [ ] **Step 3: Remove `savedHints` in `nextLevel`**

`GameProvider.nextLevel` previously carried `hintsRemaining` forward. Remove that line.

- [ ] **Step 4: Run + commit**

```bash
flutter analyze
flutter test
git add lib/models/game_state.dart lib/providers/game_provider.dart
git commit -m "refactor(state): migrate score → pendingScore; drop hintsRemaining"
```

---

## Task 4: `GameEngine.pickSafeHintLetter` with seeded RNG

**Files:**
- Modify: `lib/engine/game_engine.dart`
- Create: `test/engine/safe_hint_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/engine/safe_hint_test.dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:words_from_a_word/engine/game_engine.dart';
import 'package:words_from_a_word/models/game_state.dart';

void main() {
  group('pickSafeHintLetter', () {
    TargetWord tw(String word, {bool isBonus = false, bool isFound = false}) =>
        TargetWord(word: word, length: word.length,
                   isFound: isFound, isBonus: isBonus);

    test('picks from any unfound non-found word where revealing leaves ≥ 1 unrevealed',
        () {
      final result = GameEngine.pickSafeHintLetter(
        targetWords: [tw('star'), tw('strand')],
        revealedPositions: {},
        rng: Random(42),
      );
      expect(result, isNotNull);
      expect(result!.wordKey, anyOf('star', 'strand'));
      // The returned position for that word must leave at least 1 unrevealed letter
      final word = result.wordKey;
      final wordLen = word.length;
      expect(result.position >= 0 && result.position < wordLen, true);
      // after revealing one more, at least 1 remains unrevealed
      final remaining = wordLen - 1;
      expect(remaining >= 1, true);
    });

    test('returns null when every unfound word is one-letter-from-complete', () {
      // "cat" has 3 letters; reveal 2 → 1 left → unsafe.
      final result = GameEngine.pickSafeHintLetter(
        targetWords: [tw('cat')],
        revealedPositions: {'cat': {0, 1}},
        rng: Random(42),
      );
      expect(result, isNull);
    });

    test('skips found words', () {
      final result = GameEngine.pickSafeHintLetter(
        targetWords: [tw('cat', isFound: true), tw('dogs')],
        revealedPositions: {},
        rng: Random(42),
      );
      expect(result, isNotNull);
      expect(result!.wordKey, 'dogs');
    });

    test('includes bonus words', () {
      final result = GameEngine.pickSafeHintLetter(
        targetWords: [tw('cats', isBonus: true)],
        revealedPositions: {},
        rng: Random(42),
      );
      expect(result, isNotNull);
      expect(result!.wordKey, 'cats');
    });

    test('seeded RNG is deterministic', () {
      final a = GameEngine.pickSafeHintLetter(
        targetWords: [tw('bread'), tw('table')],
        revealedPositions: {},
        rng: Random(1234),
      );
      final b = GameEngine.pickSafeHintLetter(
        targetWords: [tw('bread'), tw('table')],
        revealedPositions: {},
        rng: Random(1234),
      );
      expect(a!.wordKey, b!.wordKey);
      expect(a.position, b.position);
    });

    test('skips already-revealed positions', () {
      final result = GameEngine.pickSafeHintLetter(
        targetWords: [tw('cat')],
        revealedPositions: {'cat': {0}}, // letters 1 and 2 remain; revealing either leaves exactly 1 unrevealed → unsafe
        rng: Random(42),
      );
      expect(result, isNull);
    });
  });
}
```

- [ ] **Step 2: Confirm failure**

Run: `flutter test test/engine/safe_hint_test.dart -v`
Expected: FAIL (`pickSafeHintLetter` + `SafeHintResult` don't exist).

- [ ] **Step 3: Implement**

In `lib/engine/game_engine.dart`:

```dart
class SafeHintResult {
  final String wordKey;   // the target word's `word` string
  final int position;     // index in the word (0-based)
  final String letter;    // convenience
  const SafeHintResult({required this.wordKey, required this.position, required this.letter});
}

static SafeHintResult? pickSafeHintLetter({
  required List<TargetWord> targetWords,
  required Map<String, Set<int>> revealedPositions,
  required Random rng,
}) {
  // Collect every (word, position) that is safe to reveal.
  // A position is safe if revealing it leaves ≥ 1 unrevealed letter.
  final candidates = <SafeHintResult>[];
  for (final tw in targetWords) {
    if (tw.isFound) continue;
    final revealed = revealedPositions[tw.word] ?? const <int>{};
    final unrevealed = <int>[];
    for (var i = 0; i < tw.word.length; i++) {
      if (!revealed.contains(i)) unrevealed.add(i);
    }
    // Safe if at least 2 unrevealed positions remain — revealing one leaves ≥ 1.
    if (unrevealed.length < 2) continue;
    for (final i in unrevealed) {
      candidates.add(SafeHintResult(
        wordKey: tw.word,
        position: i,
        letter: tw.word[i],
      ));
    }
  }
  if (candidates.isEmpty) return null;
  return candidates[rng.nextInt(candidates.length)];
}
```

**Design note (in plan, not code):** GDD §4.5 suggests a frequency-first, length-tiebreak ordering. This implementation uses uniform random across the safe candidate set — simpler and easier to test. After playtest, we may re-introduce ordering; that's a Phase-2.5 tuning change, not a v1.1 blocker.

- [ ] **Step 4: Run + commit**

```bash
flutter test test/engine/safe_hint_test.dart -v
flutter analyze
git add lib/engine/game_engine.dart test/engine/safe_hint_test.dart
git commit -m "feat(hints): safe-letter hint picker with seeded RNG"
```

---

## Task 5: `GameProvider.useHint` + rewarded-ad prompt

**Files:**
- Modify: `lib/providers/game_provider.dart`
- Modify: `test/providers/game_provider_test.dart`

- [ ] **Step 1: Add constructor injection for RewardsProvider + RNG**

```dart
class GameProvider extends ChangeNotifier {
  GameProvider({required RewardsProvider rewards, Random? rng})
      : _rewards = rewards,
        _rng = rng ?? Random();
  final RewardsProvider _rewards;
  final Random _rng;
  // ...
}
```

- [ ] **Step 2: Derived getter `hintAvailable`**

```dart
bool get hintAvailable {
  if (_state == null) return false;
  // A hint is available only if there exists a safe position AND the user has capacity.
  final hasSafe = GameEngine.pickSafeHintLetter(
    targetWords: _state!.level.targetWords,
    revealedPositions: _state!.revealedPositions,
    rng: Random(0), // just to check existence; throwaway RNG
  ) != null;
  return hasSafe && (_rewards.canUseHint || true /* rewarded-ad fallback always available */);
}
```

Note: rewarded-ad fallback is always conceptually available — the actual ad-load failure is handled later. So `hintAvailable` reduces to "is there a safe position?".

- [ ] **Step 3: Rewrite `useHint`**

```dart
void useHint() {
  if (_state == null) return;
  final safe = GameEngine.pickSafeHintLetter(
    targetWords: _state!.level.targetWords,
    revealedPositions: _state!.revealedPositions,
    rng: _rng,
  );
  if (safe == null) return; // disabled path — UI button already shows disabled

  final source = _rewards.consumeHint();
  if (source == null) {
    // Trigger rewarded-ad prompt via flag; GameScreen observes and shows sheet.
    _state = _state!.copyWith(pendingRewardedAdPrompt: true);
    notifyListeners();
    return;
  }

  _applyReveal(safe);
}

void _applyReveal(SafeHintResult safe) {
  final s = _state!;
  final updated = Map<String, Set<int>>.from(s.revealedPositions);
  final set = Set<int>.from(updated[safe.wordKey] ?? const <int>{})..add(safe.position);
  updated[safe.wordKey] = set;
  _state = s.copyWith(revealedPositions: updated);
  HapticFeedback.lightImpact();
  // audioService.playHintReveal(); // Phase 4 wires this
  notifyListeners();
}

/// Called by GameScreen after a rewarded ad is completed (Phase 5 wires the ad).
void onRewardedAdCompleted() {
  if (_state == null) return;
  _state = _state!.copyWith(pendingRewardedAdPrompt: false);
  final safe = GameEngine.pickSafeHintLetter(
    targetWords: _state!.level.targetWords,
    revealedPositions: _state!.revealedPositions,
    rng: _rng,
  );
  if (safe == null) {
    notifyListeners();
    return;
  }
  _rewards.addPurchasedHints(1);
  _rewards.consumeHint(); // should now return HintSource.purchased
  _applyReveal(safe);
}

void onRewardedAdDeclined() {
  if (_state == null) return;
  _state = _state!.copyWith(pendingRewardedAdPrompt: false);
  notifyListeners();
}
```

- [ ] **Step 4: Maybe-refill on game start**

In `startGame`, after `LevelLoader.generateLevel`, call:

```dart
_rewards.maybeRefillDailyHint();
```

- [ ] **Step 5: Provider tree update**

In `lib/main.dart`:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
    ChangeNotifierProvider(create: (_) => RewardsProvider()..load()),
    Provider<AdGateway>(create: (_) => NoopAdGateway()),
    ChangeNotifierProxyProvider<RewardsProvider, GameProvider>(
      create: (ctx) => GameProvider(rewards: ctx.read<RewardsProvider>()),
      update: (_, rewards, prev) => prev ?? GameProvider(rewards: rewards),
    ),
  ],
  child: const App(),
)
```

- [ ] **Step 6: Tests**

Write unit tests covering: hint button disabled when no safe position; hint consumes free slot when available; hint sets `pendingRewardedAdPrompt` when no slot; `onRewardedAdCompleted` reveals.

- [ ] **Step 7: Commit**

```bash
git add lib/providers/game_provider.dart lib/main.dart test/providers/game_provider_test.dart
git commit -m "feat(hints): wire safe-letter hints to RewardsProvider with ad-fallback flag"
```

---

## Task 6: Increment bonus counter on bonus-word find

**Files:**
- Modify: `lib/providers/game_provider.dart`

- [ ] **Step 1: Extend `submitWord`**

After `final points = GameEngine.scoreWord(word, isBonus: foundTarget.isBonus);`:

```dart
if (foundTarget.isBonus) {
  _rewards.incrementBonusCounter();
}
```

- [ ] **Step 2: Test**

In game-provider tests, assert that finding 10 bonus words calls `incrementBonusCounter` 10 times (mock `RewardsProvider`, or use real one and assert `bonusWordCounter` transitions through expected sequence).

- [ ] **Step 3: Commit**

```bash
git add lib/providers/game_provider.dart test/providers/game_provider_test.dart
git commit -m "feat(hints): increment bonus counter on bonus word find"
```

---

## Task 7: `bankAndAdvance` on level complete — pending → lifetime + best

**Files:**
- Modify: `lib/providers/game_provider.dart`
- Create: `test/providers/pending_score_test.dart`

- [ ] **Step 1: Failing tests**

```dart
test('complete level banks pendingScore to RewardsProvider.lifetimeScore', () async {
  final rewards = RewardsProvider();
  await rewards.load();
  final game = GameProvider(rewards: rewards);
  await game.startGame(LanguageMode.english, levelNumber: 1);
  // ... submit all required words ...
  expect(game.state.isLevelComplete, true);
  game.bankAndAdvance(LanguageMode.english);
  expect(rewards.lifetimeScore[LanguageMode.english], greaterThan(0));
});

test('abandon (startGame of new level) discards pendingScore', () async {
  final rewards = RewardsProvider();
  await rewards.load();
  final game = GameProvider(rewards: rewards);
  await game.startGame(LanguageMode.english, levelNumber: 1);
  // ... submit one word so pendingScore > 0 but level not complete ...
  expect(game.state.pendingScore, greaterThan(0));
  await game.startGame(LanguageMode.english, levelNumber: 2);
  expect(rewards.lifetimeScore[LanguageMode.english] ?? 0, 0);
});
```

- [ ] **Step 2: Confirm failure**

Run: `flutter test test/providers/pending_score_test.dart -v`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
void bankAndAdvance(LanguageMode mode) {
  if (_state == null || !_state!.isLevelComplete) return;
  _rewards.onLevelComplete(
    mode: mode,
    levelId: _state!.level.id,
    pendingScore: _state!.pendingScore,
    isReplay: _state!.isReplayMode,
  );
  // Defer `nextLevel` call to caller — so `LibraryCompleteScreen` can interpose.
}
```

Replace existing `nextLevel` callers: `LevelCompleteOverlay` now invokes `bankAndAdvance(mode)` first, then `nextLevel(mode)`. `GameScreen` wires the sequence.

- [ ] **Step 4: Run + commit**

```bash
flutter test
git add lib/providers/game_provider.dart test/providers/pending_score_test.dart
git commit -m "feat(scoring): pending-and-bank — complete path banks, abandon discards"
```

---

## Task 8: `WordSlotItem` underline treatment for revealed positions

**Files:**
- Modify: `lib/widgets/word_slot_item.dart`
- Create: `test/widgets/word_slot_item_reveal_test.dart`

- [ ] **Step 1: Extend constructor**

```dart
class WordSlotItem extends StatelessWidget {
  final TargetWord target;
  final Set<int> revealedPositions;
  // ...
}
```

- [ ] **Step 2: Failing widget test**

```dart
testWidgets('reveals render with dashed underline when revealed', (tester) async {
  final tw = TargetWord(word: 'cat', length: 3, isFound: false, isBonus: false);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: WordSlotItem(
      target: tw, revealedPositions: {0},
    ))),
  );
  // Find the widget rendering 'C' (first letter) and assert it has the underline decoration.
  final textFinder = find.text('C');
  expect(textFinder, findsOneWidget);
  // Assert underline decoration via style lookup.
});
```

- [ ] **Step 3: Implement**

In each letter cell:

```dart
final isRevealed = revealedPositions.contains(i);
final textStyle = AppTheme.tileLabel.copyWith(
  decoration: isRevealed ? TextDecoration.underline : TextDecoration.none,
  decorationStyle: TextDecorationStyle.dashed,
  decorationColor: AppTheme.border,
  decorationThickness: 1.0,
);
```

Revealed cells show the actual letter. Unrevealed cells show the existing placeholder (blank box).

- [ ] **Step 4: Run + commit**

```bash
flutter test test/widgets/word_slot_item_reveal_test.dart -v
git add lib/widgets/word_slot_item.dart test/widgets/word_slot_item_reveal_test.dart
git commit -m "feat(hints): underline treatment for revealed hint letters"
```

---

## Task 9: `ProgressStrip` widget

**Files:**
- Create: `lib/widgets/progress_strip.dart`
- Modify: `lib/screens/game_screen.dart`

- [ ] **Step 1: Build the widget**

```dart
// lib/widgets/progress_strip.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/rewards_provider.dart';
import '../theme/app_theme.dart';

class ProgressStrip extends StatelessWidget {
  final LanguageMode mode;
  const ProgressStrip({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final isRu = mode == LanguageMode.russian;
    final r = context.watch<RewardsProvider>();
    final bonus = r.bonusWordCounter;
    final banked = r.freeHintSlot + r.purchasedHintCount;

    // Hide strip if nothing to show.
    if (bonus == 0 && banked == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isRu ? StringsRu.bonusCounterLabel : StringsEn.bonusCounterLabel,
                style: AppTheme.condensedLabel,
              ),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: bonus / 10.0,
                  minHeight: 6,
                  backgroundColor: AppTheme.muted,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                ),
              ),
              Text('$bonus / 10', style: AppTheme.condensedLabel),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.lightbulb, color: AppTheme.background, size: 16),
            const SizedBox(width: 4),
            Text('$banked',
              style: AppTheme.condensedBold.copyWith(color: AppTheme.background)),
          ]),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 2: Mount in `GameScreen`**

At the top of the game screen body, above the source word:

```dart
ProgressStrip(mode: mode),
```

- [ ] **Step 3: Add strings**

`strings_en.dart`:
```dart
static const String bonusCounterLabel = 'Bonus words';
static const String bankedHintsLabel = 'Hints';
```
`strings_ru.dart`:
```dart
static const String bonusCounterLabel = 'Бонусных слов';
static const String bankedHintsLabel = 'Подсказок';
```

- [ ] **Step 4: Commit**

```bash
flutter analyze && flutter test
git add lib/widgets/progress_strip.dart lib/screens/game_screen.dart lib/l10n
git commit -m "feat(hints): top-strip progress indicator for bonus counter and hints"
```

---

## Task 10: Hint button `onPressed` honours `hintAvailable`

**Files:**
- Modify: `lib/widgets/tile_picker.dart` (or wherever the hint button lives in `game_screen.dart`)

- [ ] **Step 1: Read `hintAvailable`**

The hint button's `onPressed` becomes:

```dart
onPressed: context.watch<GameProvider>().hintAvailable
    ? () => context.read<GameProvider>().useHint()
    : null,
```

Null `onPressed` makes Material buttons render as disabled — no need for a manual disabled style.

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/tile_picker.dart
git commit -m "feat(hints): disable hint button when no safe position exists"
```

---

## Task 11: `FreeHintEarnedOverlay` driven by `ValueNotifier<int>` tick

**Files:**
- Modify: `lib/providers/rewards_provider.dart`
- Create: `lib/widgets/free_hint_earned_overlay.dart`
- Modify: `lib/screens/game_screen.dart`

- [ ] **Step 1: Add tick source**

In `RewardsProvider`:

```dart
final ValueNotifier<int> freeHintEarnedTicks = ValueNotifier<int>(0);
```

Fire from `incrementBonusCounter` at threshold:

```dart
void incrementBonusCounter() {
  _bonusWordCounter += 1;
  if (_bonusWordCounter >= 10 && _freeHintSlot < _slotCap) {
    _bonusWordCounter -= 10;
    _freeHintSlot += 1;
    freeHintEarnedTicks.value = freeHintEarnedTicks.value + 1;
  } else if (_bonusWordCounter >= 10 && _freeHintSlot >= _slotCap) {
    _bonusWordCounter = 10; // freeze at 10
  }
  save();
  notifyListeners();
}
```

- [ ] **Step 2: Build the overlay**

```dart
// lib/widgets/free_hint_earned_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/rewards_provider.dart';
import '../theme/app_theme.dart';

class FreeHintEarnedOverlay extends StatefulWidget {
  final LanguageMode mode;
  const FreeHintEarnedOverlay({super.key, required this.mode});

  @override
  State<FreeHintEarnedOverlay> createState() => _State();
}

class _State extends State<FreeHintEarnedOverlay> {
  bool _show = false;
  int _lastTick = 0;

  @override
  void initState() {
    super.initState();
    _lastTick = context.read<RewardsProvider>().freeHintEarnedTicks.value;
    context.read<RewardsProvider>().freeHintEarnedTicks.addListener(_onTick);
  }

  @override
  void dispose() {
    context.read<RewardsProvider>().freeHintEarnedTicks.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    final v = context.read<RewardsProvider>().freeHintEarnedTicks.value;
    if (v > _lastTick) {
      _lastTick = v;
      setState(() => _show = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _show = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final isRu = widget.mode == LanguageMode.russian;
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _show = false),
        child: Container(
          color: AppTheme.foreground.withValues(alpha: 0.4),
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lightbulb, color: AppTheme.accent, size: 48),
              const SizedBox(height: 12),
              Text(
                isRu ? StringsRu.freeHintEarnedTitle : StringsEn.freeHintEarnedTitle,
                style: AppTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isRu ? StringsRu.freeHintEarnedBody : StringsEn.freeHintEarnedBody,
                style: AppTheme.condensedBold, textAlign: TextAlign.center,
              ),
            ]),
          ),
        ),
      ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.9,0.9)),
    );
  }
}
```

Add strings:

`strings_en.dart`:
```dart
static const String freeHintEarnedTitle = 'Free hint earned!';
static const String freeHintEarnedBody = '10 bonus words — one hint is yours.';
```
`strings_ru.dart`:
```dart
static const String freeHintEarnedTitle = 'Подсказка заработана!';
static const String freeHintEarnedBody = '10 бонусных слов — одна подсказка ваша.';
```

- [ ] **Step 3: Mount in `GameScreen`**

Stack the overlay on top of the game body:

```dart
Stack(children: [
  // existing game body
  FreeHintEarnedOverlay(mode: mode),
]),
```

- [ ] **Step 4: Commit**

```bash
flutter test && flutter analyze
git add lib/providers/rewards_provider.dart lib/widgets/free_hint_earned_overlay.dart lib/screens/game_screen.dart lib/l10n
git commit -m "feat(hints): celebratory popup on bonus-word refill"
```

---

## Task 12: Rewrite `rulesHint` and `rulesScore` copy

**Files:**
- Modify: `lib/l10n/strings_en.dart`
- Modify: `lib/l10n/strings_ru.dart`

- [ ] **Step 1: English rewrite**

```dart
static const String rulesHint =
    'Hints: tap the lightbulb to reveal one safe letter in an unsolved word — never the last one. Earn free hints by finding 10 bonus words, or watch a short ad.';
static const String rulesScore =
    'Scoring: 10 points per letter, with length bonuses for 4+ letter words. Bonus words give a flat 15 points. Your score banks when the level is complete — abandon mid-level and it is lost.';
```

- [ ] **Step 2: Russian rewrite**

```dart
static const String rulesHint =
    'Подсказки: нажмите лампочку, чтобы открыть одну безопасную букву в неразгаданном слове — никогда не последнюю. Бесплатные подсказки выдаются за 10 бонусных слов или за просмотр короткой рекламы.';
static const String rulesScore =
    'Очки: 10 за букву, с бонусом за слова от 4 букв. Бонусные слова дают 15 очков. Очки засчитываются только после прохождения уровня — если выйти в середине, они пропадают.';
```

- [ ] **Step 3: Commit**

```bash
git add lib/l10n
git commit -m "docs(hints): rewrite rulesHint and rulesScore copy for v1.1 economy"
```

---

## Task 13: `RewardsProvider.maybeRefillDailyHint` with injectable `nowProvider`

**Files:**
- Modify: `lib/providers/rewards_provider.dart`
- Create: `test/providers/free_hint_refill_test.dart`

- [ ] **Step 1: Inject `nowProvider`**

```dart
class RewardsProvider extends ChangeNotifier {
  RewardsProvider({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  // ...
}
```

(If Phase 1 already added this, skip — Phase 3 also depends on it.)

- [ ] **Step 2: Failing tests**

```dart
test('refills once per day when slot not full', () async {
  DateTime now = DateTime(2026, 4, 16, 10);
  final p = RewardsProvider(clock: () => now);
  await p.load();
  // start: freeHintSlot = 0
  p.maybeRefillDailyHint();
  expect(p.freeHintSlot, 1);

  // same day — no refill
  p.maybeRefillDailyHint();
  expect(p.freeHintSlot, 1);

  // next day — refill again (but slot full, so no change unless cap > 1)
  now = DateTime(2026, 4, 17, 10);
  // consume first to make room
  p.consumeHint();
  p.maybeRefillDailyHint();
  expect(p.freeHintSlot, 1);
});

test('refill respects cap', () async {
  DateTime now = DateTime(2026, 4, 16);
  final p = RewardsProvider(clock: () => now);
  await p.load();
  // cap = 1 for free users
  p.maybeRefillDailyHint();
  // Next day, slot still full — no change
  now = DateTime(2026, 4, 17);
  p.maybeRefillDailyHint();
  expect(p.freeHintSlot, 1);
});

test('premium user can bank up to 3', () async {
  DateTime now = DateTime(2026, 4, 16);
  final p = RewardsProvider(clock: () => now);
  await p.load();
  p.markPremium();
  p.maybeRefillDailyHint();
  now = DateTime(2026, 4, 17);
  p.maybeRefillDailyHint();
  now = DateTime(2026, 4, 18);
  p.maybeRefillDailyHint();
  expect(p.freeHintSlot, 3);
});
```

- [ ] **Step 3: Implement**

```dart
void maybeRefillDailyHint() {
  final today = _dateOnly(_clock());
  if (_lastDailyClaimedOn != null && _lastDailyClaimedOn == today) return;
  final cap = _premium ? 3 : 1;
  if (_freeHintSlot >= cap) {
    _lastDailyClaimedOn = today;
    save();
    notifyListeners();
    return;
  }
  _freeHintSlot += 1;
  _lastDailyClaimedOn = today;
  save();
  notifyListeners();
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
```

- [ ] **Step 4: Run + commit**

```bash
flutter test test/providers/free_hint_refill_test.dart -v
git add lib/providers/rewards_provider.dart test/providers/free_hint_refill_test.dart
git commit -m "feat(hints): daily free-hint refill honours cap and clock injection"
```

---

## Task 14: End-to-end verification

**Files:** none — verification sweep

- [ ] **Step 1**: `flutter analyze` — expect `No issues found!`.
- [ ] **Step 2**: `flutter test` — expect all green. Count should be ≥ current count + 15 new tests.
- [ ] **Step 3**: Manual device smoke:
  - Start level, submit valid word — `pendingScore` increments.
  - Tap hint — letter reveals with underline in a word slot.
  - Submit 10 bonus words — `FreeHintEarnedOverlay` fires.
  - Complete level — `pendingScore` banked into lifetime.
  - Start new level from partial progress — old pending discarded.
  - Reveal enough letters to exhaust safe positions — hint button disables.
- [ ] **Step 4**: Tag: `git tag phase-2-complete`.

---

## Exit criteria (verified)

- [x] Hints never complete a word (safe-letter algorithm + unit tests).
- [x] Hint button disables when no safe position exists.
- [x] Pending-and-bank scoring: complete → banked, abandon → discarded.
- [x] Bonus words score flat 15.
- [x] 10 bonus words earn a free hint; celebratory popup fires.
- [x] Daily hint refill respects cap + clock injection.
- [x] Word slot revealed letters show dashed underline.
- [x] Top strip shows bonus counter (x/10) + banked hints; hides when both 0.
- [x] Rules modal copy rewritten in RU and EN.
- [x] `flutter analyze` clean; `flutter test` all pass.

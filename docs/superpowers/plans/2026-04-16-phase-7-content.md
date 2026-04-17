# Phase 7 — Content Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Grow the level library from 23 RU + 20 EN to **50 RU + 50 EN**, add a `difficulty` field (1..5) to the JSON schema, tag every level with a difficulty rating, and reorder the JSON so difficulty climbs deliberately. Provide a CLI validator that every level passes (word-formation + difficulty + required-word-count rules).

**Architecture:** Level data lives in `assets/data/russian_levels.json` and `assets/data/english_levels.json`. `LevelLoader.generateLevel` already infers level ID from array position (Phase 0 decision). New: schema gains optional `difficulty: int (1..5)`. `GameLevel` model gets a nullable `difficulty` field. A new Dart CLI script `tool/validate_levels.dart` runs `GameEngine.canFormWord` on every required + bonus word and enforces schema rules. CI runs this before tests.

**Tech Stack:** Dart 3.11, existing `GameEngine.canFormWord`, no new packages.

---

## File Structure

- **Create**
  - `tool/validate_levels.dart` — CLI entry: loads both JSON files, validates every level, prints report, exits non-zero on any failure.
  - `tool/README.md` — short doc on `dart run tool/validate_levels.dart`.
  - `docs/LEVEL_AUTHORING.md` — guide for level authors (difficulty rubric, word-count rules, validator usage).
  - `test/engine/level_loader_difficulty_test.dart` — verifies `difficulty` parsing + null default.

- **Modify**
  - `lib/models/game_state.dart` — `GameLevel` gains `int? difficulty`.
  - `lib/engine/level_loader.dart` — parse `difficulty` field into `GameLevel`.
  - `assets/data/russian_levels.json` — tag all 23 existing levels + add 27 new levels = 50 total.
  - `assets/data/english_levels.json` — tag all 20 existing levels + add 30 new levels = 50 total.
  - `pubspec.yaml` — no change (Dart `dart:io` only for CLI).

---

## Difficulty rubric

Author-facing (also put in `docs/LEVEL_AUTHORING.md`):

| Level | Source length | Target words | Avg target length | Bonus words | Gotchas |
|---|---|---|---|---|---|
| 1 — Warm-up | 5-6 letters | 4-6 | 3-4 | 0-1 | No tricky letters; all obvious |
| 2 — Easy | 6-7 | 6-8 | 3-4 | 1-2 | One moderately obscure word |
| 3 — Medium | 7-8 | 7-10 | 4-5 | 2-3 | Words need some vocabulary |
| 4 — Hard | 8-9 | 8-12 | 4-6 | 3-4 | At least one uncommon word |
| 5 — Challenge | 9-10 | 10-12 | 5-7 | 4-5 | Requires flexible thinking |

Target distribution across 50 levels: ~10 at 1, ~15 at 2, ~15 at 3, ~7 at 4, ~3 at 5 (rising curve with more bottom-weighted levels so early-drop-off users hit success first).

---

## Word-count rules (hard constraints; validator enforces)

- `required.length >= 4` and `<= 12`. (v1.0 cap is 12.)
- `bonus.length <= 6`.
- Every required word length ≥ 3.
- No duplicates within or across `required` and `bonus`.
- Every word must be formable from `sourceWord` via `GameEngine.canFormWord` (letter-count-respecting).

---

## Task 1: Add `difficulty` to `GameLevel`

**Files:**
- Modify: `lib/models/game_state.dart`
- Create: `test/engine/level_loader_difficulty_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/engine/level_loader_difficulty_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slova_iz_slova/engine/level_loader.dart';
import 'package:slova_iz_slova/models/language_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Stub the asset bundle
    const jsonLevels = '''
    [
      {
        "sourceWord": "strawberry",
        "required": ["bar", "star"],
        "bonus": ["berry"],
        "difficulty": 3
      },
      {
        "sourceWord": "apple",
        "required": ["app", "pal"],
        "bonus": []
      }
    ]
    ''';
    const channel = MethodChannel('flutter/assets');
    channel.setMockMethodCallHandler((call) async {
      if (call.method == 'load' &&
          call.arguments == 'assets/data/english_levels.json') {
        return ByteData.view(
            Uint8List.fromList(jsonLevels.codeUnits).buffer);
      }
      return null;
    });
  });

  test('parses difficulty when present', () async {
    await LevelLoader.preload();
    final level = LevelLoader.generateLevel(1, LanguageMode.english);
    expect(level.difficulty, 3);
  });

  test('difficulty is null when missing', () async {
    await LevelLoader.preload();
    final level = LevelLoader.generateLevel(2, LanguageMode.english);
    expect(level.difficulty, isNull);
  });
}
```

(Note: the asset mocking approach above is simplified — adapt to whatever stub pattern the existing test suite uses. If `LevelLoader.preload()` is already called in `main.dart` at startup and the existing test suite mocks differently, mirror the existing approach.)

- [ ] **Step 2: Run (fail)**

Run: `flutter test test/engine/level_loader_difficulty_test.dart`
Expected: FAIL — `difficulty` field doesn't exist.

- [ ] **Step 3: Add field to `GameLevel`**

In `lib/models/game_state.dart`, add `difficulty` to the `GameLevel` class:

```dart
class GameLevel {
  const GameLevel({
    required this.id,
    required this.sourceWord,
    required this.tiles,
    required this.targetWords,
    this.difficulty,
  });

  final int id;
  final String sourceWord;
  final List<LetterTile> tiles;
  final List<TargetWord> targetWords;
  final int? difficulty;

  GameLevel copyWith({...existing..., int? difficulty}) => GameLevel(
    ...existing...,
    difficulty: difficulty ?? this.difficulty,
  );
}
```

- [ ] **Step 4: Parse in `LevelLoader`**

In `lib/engine/level_loader.dart`, within the JSON→`GameLevel` construction:

```dart
  final difficulty = raw['difficulty'] is int ? raw['difficulty'] as int : null;
  return GameLevel(
    id: levelNumber,
    sourceWord: sourceWord,
    tiles: tiles,
    targetWords: targetWords,
    difficulty: difficulty,
  );
```

- [ ] **Step 5: Run + commit**

```bash
flutter test test/engine/level_loader_difficulty_test.dart
# expected PASS

git add lib/models/game_state.dart lib/engine/level_loader.dart test/engine/level_loader_difficulty_test.dart
git commit -m "feat: add optional difficulty field (1..5) to GameLevel schema"
```

---

## Task 2: Build the level-validator CLI

**Files:**
- Create: `tool/validate_levels.dart`
- Create: `tool/README.md`

- [ ] **Step 1: Write the CLI**

Create `tool/validate_levels.dart`:

```dart
// Run with: dart run tool/validate_levels.dart
//
// Validates every level in assets/data/{russian,english}_levels.json.
// Exits 0 if all pass, non-zero with a per-level report otherwise.

import 'dart:convert';
import 'dart:io';

void main() async {
  final files = {
    'ru': 'assets/data/russian_levels.json',
    'en': 'assets/data/english_levels.json',
  };

  var totalErrors = 0;

  for (final entry in files.entries) {
    final mode = entry.key;
    final path = entry.value;
    stdout.writeln('\n=== $mode ($path) ===');

    final raw = await File(path).readAsString();
    final levels = jsonDecode(raw) as List<dynamic>;

    stdout.writeln('levels: ${levels.length}');

    for (var i = 0; i < levels.length; i++) {
      final lvl = levels[i] as Map<String, dynamic>;
      final errors = _validateLevel(lvl, i + 1);
      if (errors.isNotEmpty) {
        stdout.writeln('  [FAIL] level ${i + 1} "${lvl['sourceWord']}":');
        for (final e in errors) {
          stdout.writeln('    - $e');
          totalErrors++;
        }
      }
    }

    // Library-size check
    if (levels.length < 50) {
      stdout.writeln('  [WARN] only ${levels.length} levels; target is 50');
    }

    // Difficulty distribution
    final byDiff = <int, int>{};
    for (final l in levels) {
      final d = (l as Map)['difficulty'] as int?;
      if (d != null) byDiff[d] = (byDiff[d] ?? 0) + 1;
    }
    stdout.writeln('  difficulty histogram: $byDiff');
  }

  if (totalErrors > 0) {
    stdout.writeln('\nTOTAL ERRORS: $totalErrors');
    exit(1);
  }
  stdout.writeln('\nAll levels valid.');
}

List<String> _validateLevel(Map<String, dynamic> lvl, int pos) {
  final errors = <String>[];

  final source = lvl['sourceWord'] as String?;
  if (source == null || source.isEmpty) {
    errors.add('missing sourceWord');
    return errors;
  }
  final required = (lvl['required'] as List<dynamic>?)?.cast<String>() ?? [];
  final bonus = (lvl['bonus'] as List<dynamic>?)?.cast<String>() ?? [];
  final diff = lvl['difficulty'];

  if (required.length < 4) errors.add('required has ${required.length} words (< 4)');
  if (required.length > 12) errors.add('required has ${required.length} words (> 12)');
  if (bonus.length > 6) errors.add('bonus has ${bonus.length} words (> 6)');

  if (diff != null) {
    if (diff is! int) errors.add('difficulty not int: $diff');
    else if (diff < 1 || diff > 5) errors.add('difficulty out of 1..5: $diff');
  }

  // Duplicate check
  final all = [...required, ...bonus];
  final dupes = <String>{};
  final seen = <String>{};
  for (final w in all) {
    if (!seen.add(w)) dupes.add(w);
  }
  if (dupes.isNotEmpty) errors.add('duplicates: $dupes');

  // Word length
  for (final w in required) {
    if (w.length < 3) errors.add('required word too short: $w');
  }

  // canFormWord check (pure Dart — duplicates engine logic so CLI doesn't
  // import Flutter packages)
  for (final w in all) {
    if (!_canFormWord(w, source)) {
      errors.add('cannot form "$w" from "$source"');
    }
  }

  return errors;
}

bool _canFormWord(String word, String source) {
  final counts = <String, int>{};
  for (final c in source.toLowerCase().split('')) {
    counts[c] = (counts[c] ?? 0) + 1;
  }
  for (final c in word.toLowerCase().split('')) {
    final n = counts[c] ?? 0;
    if (n == 0) return false;
    counts[c] = n - 1;
  }
  return true;
}
```

- [ ] **Step 2: Write `tool/README.md`**

```markdown
# Content tools

## validate_levels.dart

Run:

```
dart run tool/validate_levels.dart
```

Exits 0 if both `assets/data/russian_levels.json` and `assets/data/english_levels.json`
pass the schema and word-formation rules. Otherwise prints failures and exits 1.

## Rules enforced

- `required.length` between 4 and 12
- `bonus.length` <= 6
- `difficulty` (if present) is an int in 1..5
- No duplicate words within or across `required` + `bonus`
- Every word in `required` has length ≥ 3
- Every word can be formed from `sourceWord` (letter counts respected)
```

- [ ] **Step 3: Run validator against current content**

Run: `dart run tool/validate_levels.dart`
Expected: pass for existing 23 RU + 20 EN. (WARN on under-50 count.)
Fix any failures the validator surfaces (unlikely given v1.0 was audited in D7, but sanity-check).

- [ ] **Step 4: Commit**

```bash
git add tool/validate_levels.dart tool/README.md
git commit -m "feat: add dart CLI validator for level content"
```

---

## Task 3: Author RU levels 24-40 (medium pass, difficulty 2-3)

**Files:**
- Modify: `assets/data/russian_levels.json`

- [ ] **Step 1: Read existing RU levels**

Open `assets/data/russian_levels.json`. Note existing source words and vibe.

- [ ] **Step 2: Author 17 new levels**

Add 17 new level objects (positions 24-40 in the array). For each:
1. Pick a source word (6-8 letters, high-frequency Russian noun/verb).
2. Brainstorm 6-10 required target words (length ≥3) formable from it.
3. Add 2-3 bonus words.
4. Tag `"difficulty": 2` or `"difficulty": 3` per rubric.
5. Run validator after every 3-4 levels: `dart run tool/validate_levels.dart`.

Example shape:

```json
{
  "sourceWord": "книга",
  "required": ["нога", "кнопа", "кон", "ник", "иго"],
  "bonus": ["гик"],
  "difficulty": 2
}
```

(These are illustrative — replace with author's vetted choices.)

- [ ] **Step 3: Validate + commit**

Run: `dart run tool/validate_levels.dart`
Expected: all pass. WARN still shown (not yet 50).

```bash
git add assets/data/russian_levels.json
git commit -m "content: add 17 RU levels (difficulty 2-3) — positions 24-40"
```

---

## Task 4: Author RU levels 41-50 (hard pass, difficulty 4-5)

**Files:**
- Modify: `assets/data/russian_levels.json`

- [ ] **Step 1: Author 10 harder levels**

Same process as Task 3 but targeting difficulty 4 (7 levels) and difficulty 5 (3 levels). Source words 8-10 letters. 8-12 required words. 3-5 bonus words. Include at least one uncommon word per level.

- [ ] **Step 2: Validate**

Run: `dart run tool/validate_levels.dart`
Expected: all pass. RU count is now 50.

- [ ] **Step 3: Commit**

```bash
git add assets/data/russian_levels.json
git commit -m "content: add 10 RU levels (difficulty 4-5) — positions 41-50"
```

---

## Task 5: Tag existing RU levels 1-23 with difficulty

**Files:**
- Modify: `assets/data/russian_levels.json`

- [ ] **Step 1: Manually rate each existing level**

Open each existing level 1-23. Use the rubric:
- Source length 5-6, few simple words → 1
- Source length 6-7, standard words → 2
- Source length 7-8, some vocabulary → 3
- Source length 8-9, some uncommon → 4
- Source length 9-10, tricky → 5

Add `"difficulty": N` to each.

- [ ] **Step 2: Validate**

Run: `dart run tool/validate_levels.dart`
Expected: all pass. Histogram shows 50 RU levels with difficulty distribution near target (roughly 10/15/15/7/3).

- [ ] **Step 3: Commit**

```bash
git add assets/data/russian_levels.json
git commit -m "content: tag existing RU levels 1-23 with difficulty ratings"
```

---

## Task 6: Reorder RU levels by deliberate difficulty curve

**Files:**
- Modify: `assets/data/russian_levels.json`

- [ ] **Step 1: Design the curve**

Target position → difficulty:
- 1-3: 1
- 4-8: 1 or 2 (mostly 2)
- 9-15: 2
- 16-25: 2 or 3 (mostly 3)
- 26-35: 3
- 36-42: 3 or 4 (mostly 4)
- 43-47: 4
- 48-50: 5

- [ ] **Step 2: Reorder the JSON array**

Sort manually to match the curve. Use a Dart snippet or text editor. Keep each level object intact; only their positions change.

- [ ] **Step 3: Validate**

Run: `dart run tool/validate_levels.dart`
Expected: all pass.

- [ ] **Step 4: Smoke test in-game**

Run: `flutter run`, pick Russian. Play levels 1, 10, 25, 40, 50. Confirm the subjective difficulty feels right at each stop. Adjust positions if needed.

- [ ] **Step 5: Commit**

```bash
git add assets/data/russian_levels.json
git commit -m "content: reorder RU levels by deliberate difficulty curve"
```

---

## Task 7: Author EN levels 21-40 (medium pass, difficulty 2-3)

**Files:**
- Modify: `assets/data/english_levels.json`

- [ ] **Step 1: Author 20 new levels**

Same process as Task 3 but English. Target difficulty 2 (10 levels) and 3 (10 levels).

- [ ] **Step 2: Validate + commit**

```bash
dart run tool/validate_levels.dart
git add assets/data/english_levels.json
git commit -m "content: add 20 EN levels (difficulty 2-3) — positions 21-40"
```

---

## Task 8: Author EN levels 41-50 (hard pass, difficulty 4-5)

**Files:**
- Modify: `assets/data/english_levels.json`

- [ ] **Step 1: Author 10 levels**

7 at difficulty 4, 3 at difficulty 5.

- [ ] **Step 2: Validate + commit**

```bash
dart run tool/validate_levels.dart
git add assets/data/english_levels.json
git commit -m "content: add 10 EN levels (difficulty 4-5) — positions 41-50"
```

---

## Task 9: Tag existing EN levels 1-20 with difficulty

Same as Task 5 but English. Commit: `content: tag existing EN levels 1-20 with difficulty ratings`.

---

## Task 10: Reorder EN levels by deliberate difficulty curve

Same as Task 6 but English. Commit: `content: reorder EN levels by deliberate difficulty curve`.

---

## Task 11: Expose difficulty in level picker

**Files:**
- Modify: `lib/screens/level_picker_screen.dart` (from Phase 3)
- Modify: `lib/widgets/level_picker_tile.dart` (from Phase 3)

- [ ] **Step 1: Show difficulty as pips**

In `LevelPickerTile`, if `level.difficulty != null`, render 1-5 small dots below the level number, filled up to the difficulty value. Use `AppTheme.primary` for filled, `AppTheme.muted` for empty.

```dart
Widget _difficultyPips(int difficulty) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Container(
      width: 4, height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: i < difficulty ? AppTheme.primary : AppTheme.muted,
        shape: BoxShape.circle,
      ),
    )),
  );
}
```

- [ ] **Step 2: Add Semantics label**

Wrap the pips in `Semantics(label: 'Difficulty $difficulty of 5')` for accessibility (Phase 8 will audit).

- [ ] **Step 3: Analyze + commit**

```bash
flutter analyze
git add lib/widgets/level_picker_tile.dart
git commit -m "feat: show difficulty pips in level picker tiles"
```

---

## Task 12: Add content-validator to CI

**Files:**
- `.github/workflows/ci.yml` (defined in Phase 9; if not yet present, defer this task to Phase 9's CI step)

- [ ] **Step 1: Add validator step**

In `.github/workflows/ci.yml` under the test job, add:

```yaml
      - name: Validate level content
        run: dart run tool/validate_levels.dart
```

Place before `flutter analyze`.

- [ ] **Step 2: Push + verify**

Push and confirm the step runs + passes on CI.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add level-validator step"
```

---

## Task 13: Write authoring guide

**Files:**
- Create: `docs/LEVEL_AUTHORING.md`

- [ ] **Step 1: Draft the doc**

Create `docs/LEVEL_AUTHORING.md`:

```markdown
# Level authoring guide

## Where

- Russian: `assets/data/russian_levels.json`
- English: `assets/data/english_levels.json`

## Schema

```json
{
  "sourceWord": "книга",
  "required": ["нога", "кон", "ник", "иго"],
  "bonus": ["гик"],
  "difficulty": 2
}
```

- `sourceWord`: 5-10 letters. Everyday, recognizable.
- `required`: 4-12 words; length ≥ 3.
- `bonus`: 0-6 words; any length ≥ 3.
- `difficulty`: 1-5 per rubric below.

## Difficulty rubric

| Level | Source length | Targets | Avg len | Bonus | Gotchas |
|-|-|-|-|-|-|
| 1 | 5-6 | 4-6 | 3-4 | 0-1 | No tricky letters |
| 2 | 6-7 | 6-8 | 3-4 | 1-2 | One moderate obscurity |
| 3 | 7-8 | 7-10 | 4-5 | 2-3 | Needs vocab |
| 4 | 8-9 | 8-12 | 4-6 | 3-4 | Uncommon words |
| 5 | 9-10 | 10-12 | 5-7 | 4-5 | Flex thinking |

## Workflow

1. Pick a source word.
2. Brainstorm 6-12 required + 2-5 bonus.
3. Add to JSON.
4. Run `dart run tool/validate_levels.dart`.
5. Fix any failures.
6. Open `flutter run`, play the level. Adjust if pacing feels off.
7. Commit with message `content: <short description>`.

## Tips

- Look for high-utility letters (RU: р, т, н, а, е, и, о; EN: s, e, a, r, t, i, n).
- Avoid obscure archaic words unless difficulty 5.
- Bonus words should feel like discoveries — surprising but fair.
```

- [ ] **Step 2: Commit**

```bash
git add docs/LEVEL_AUTHORING.md
git commit -m "docs: add level authoring guide"
```

---

## Task 14: Final verification

- [ ] **Step 1: Validator passes**

Run: `dart run tool/validate_levels.dart`
Expected: zero errors, 50 RU + 50 EN, histograms near target distribution.

- [ ] **Step 2: Analyze + test**

Run: `flutter analyze && flutter test`
Expected: clean.

- [ ] **Step 3: In-game spot checks**

Play RU level 1, 25, 50. Play EN level 1, 25, 50. Confirm:
- Each level loads without error.
- Difficulty pips match JSON.
- Curve feels progressive.

- [ ] **Step 4: Tag**

```bash
git tag phase-7-content-complete
```

---

## Exit criteria recap

- 50 RU + 50 EN levels in JSON.
- Every level has `difficulty: 1..5`.
- Levels ordered by deliberate curve (roughly 1→5).
- `dart run tool/validate_levels.dart` exits 0.
- Authoring guide exists.
- Level picker shows difficulty pips.

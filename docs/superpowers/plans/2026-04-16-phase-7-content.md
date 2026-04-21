# Phase 7 — Content Implementation Plan (v2 rewrite)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

---

## v2 baseline reconciliation (2026-04-21)

This plan was originally authored as a manual level-authoring effort against v1.0. It has been fully rewritten for v2. On v2, content generation is owned by an offline Python pipeline under `tools/level_generator/` (see DECISIONS.md D10–D16), calibration is driven by `calibrate_ru.py` / `calibrate_en.py` with median-based corpus anchoring, and Kat owns the generator + content authoring workflow.

**This phase no longer authors words by hand.** The engineering team's responsibility is the *infrastructure* that receives Kat's generator output: the schema contract, validator CLI, level-picker difficulty display, CI gate, and the handoff brief that tells Kat exactly which source-word gaps need filling.

---

## Goal

Scale the level library to **100 levels per language, 20 per difficulty bucket** (beginner / easy / medium / hard / expert), where:

- **Source words** on the 23 RU + 20 EN levels currently in `assets/data/*.json` are kept as-is. They become the first 23 RU / 20 EN of the 100-per-language target.
- **New source words** (77 RU + 80 EN — see distribution below) are authored + calibrated by Kat using the existing generator pipeline. Required/bonus/tooCommon word lists for the new source words are produced by `generate_ru.py` / `generate_en.py` plus optional manual overrides in `manual_assignments_{ru,en}.json`.
- **The engineering team produces no JSON content**. Our contribution is the infrastructure that accepts Kat's output cleanly.

### Target distribution per language

| Difficulty | Current RU | Current EN | Target per lang | Gap RU | Gap EN |
|---|---|---|---|---|---|
| beginner | 4 | 5 | 20 | +16 | +15 |
| easy | 9 | 7 | 20 | +11 | +13 |
| medium | 6 | 5 | 20 | +14 | +15 |
| hard | 1 | 3 | 20 | +19 | +17 |
| expert | 3 | 0 | 20 | +17 | +20 |
| **Totals** | 23 | 20 | 100 | **+77 RU** | **+80 EN** |

---

## Architecture

- Level data lives in `assets/data/russian_levels.json` and `assets/data/english_levels.json`. Each entry has the shape `{ sourceWord, required, bonus, tooCommon, difficulty, levelNumber, blocked? }`.
- `GameLevel` model on v2 already has `final LevelDifficulty difficulty` (`enum { beginner, easy, medium, hard, expert }`).
- `LevelLoader.generateLevel` on v2 already parses `difficulty` string into the enum via `_parseDifficulty`.
- `tools/level_generator/generate_{ru,en}.py` produces JSON from frequency lists + hunspell gate + POS filter + per-profile thresholds. Output format is already loader-compatible.
- `tools/level_generator/calibrate_{ru,en}.py` walks source words through the generator and suggests profile assignments using log-scale median distance. Manual overrides in `manual_assignments_{ru,en}.json`.
- **Kat's workflow** (not engineering's): pick new source-word candidates → run calibrator → review near-miss words → accept suggestions / set manual overrides → run generator → commit the updated JSON.
- **Engineering's additions** from this phase: validator CLI for loader-side invariants, level-picker difficulty pip, CI hook, authoring/handoff docs.

---

## Tech Stack

Dart 3.11, existing `GameEngine.canFormWord`. No new Flutter packages. Python tooling under `tools/level_generator/` is pre-existing and owned by Kat (do not modify as part of this phase).

---

## File Structure

- **Create**
  - `tool/validate_levels.dart` — Dart CLI: loads both JSON files, validates loader-side invariants, prints report, exits non-zero on any failure.
  - `tool/README.md` — documents `dart run tool/validate_levels.dart` and the calibration gate.
  - `docs/LEVEL_AUTHORING.md` — handoff guide for Kat (source-word criteria, calibrator protocol, manual-assignments protocol, commit conventions).
  - `docs/v2/CONTENT_HANDOFF.md` — distribution gap brief for Kat (which difficulty buckets need how many more source words; example source-word seeds acceptable to the corpus).
  - `.github/workflows/content-validate.yml` — CI gate that runs `dart run tool/validate_levels.dart` on every PR touching `assets/data/*.json`.
  - `test/engine/level_loader_v2_test.dart` — widget-bundle-stubbed tests for `LevelLoader` behaviour against the v2 schema (difficulty parsing, tooCommon propagation, out-of-range throw — see Phase 3 Task 1 for the throw).

- **Modify**
  - `lib/widgets/level_picker_tile.dart` (will exist after Phase 3) — add difficulty pip rendering. This task is **owned by Phase 3** and only called out here for coordination.
  - `pubspec.yaml` — no change expected.

- **Do NOT modify in this phase**
  - `assets/data/russian_levels.json`, `assets/data/english_levels.json` — content changes are Kat's, not engineering's. Engineering commits only schema-shape fixes if the validator identifies any.
  - `tools/level_generator/**` — Kat's domain.

---

## Word-count and schema constraints (validator enforces)

Loader-side invariants, per level:

- `sourceWord` is a non-empty lowercase string.
- `required` is a JSON array of lowercase strings. Every element is formable from `sourceWord` via `GameEngine.canFormWord`.
- `bonus` is a JSON array of lowercase strings. Every element is formable and no duplicates vs `required`.
- `tooCommon` is a JSON array of lowercase strings. Every element is formable and no duplicates vs `required` or `bonus`.
- `difficulty` is one of `{beginner, easy, medium, hard, expert}`.
- `levelNumber` is a positive integer and is unique within the (language, difficulty) bucket.
- **Soft warnings (printed but do not fail)**: required length < 5 or > 15, bonus length > 8, missing `tooCommon` array.

**Note:** Per-difficulty word-count targets (e.g. "beginner has 5–7 required words") are the calibrator's concern, not the loader's. The validator does not enforce them — they're properties of `PROFILES` in `generate_{ru,en}.py`.

---

## Difficulty rubric (reference only — owned by generator `PROFILES`)

The 5-bucket LevelDifficulty enum is a stable public contract. The generator maps profile parameters (`freq_threshold`, `max_freq`, `max_length`, word-count targets) to these buckets. See DECISIONS.md D16 for the P1–P10 roadmap; the current 5 buckets are a contraction of that full scheme, as defined in `PROFILES` on each generator.

| Bucket | Intended feel | Source length heuristic | Required-count target |
|---|---|---|---|
| beginner | Warm-up; all obvious | 5–7 letters | 5–7 |
| easy | One semi-obscure | 6–8 | 6–8 |
| medium | Some vocabulary | 7–9 | 8–10 |
| hard | One uncommon | 8–10 | 10–12 |
| expert | Flexible thinking | 9–11 | 10–14 |

**These numbers are not enforced by engineering.** They describe Kat's calibration intent for reviewers.

---

## Task 1: Validator CLI — `tool/validate_levels.dart`

**Files:**
- Create: `tool/validate_levels.dart`
- Create: `tool/README.md`
- Create: `test/tool/validate_levels_test.dart` (invokes the validator against a fixture JSON string)

- [ ] **Step 1: Failing test**

Create `test/tool/validate_levels_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import '../../tool/validate_levels.dart' show validateLevelBlob, ValidationReport;

void main() {
  group('validateLevelBlob', () {
    test('passes a well-formed level', () {
      const jsonBlob = '''
      [
        {
          "sourceWord": "strawberry",
          "required": ["berry", "straw", "raw"],
          "bonus": ["bay"],
          "tooCommon": ["a", "at"],
          "difficulty": "easy",
          "levelNumber": 1
        }
      ]
      ''';
      final report = validateLevelBlob(jsonBlob, language: 'en');
      expect(report.errors, isEmpty);
    });

    test('fails when a required word cannot be formed', () {
      const jsonBlob = '''
      [
        {
          "sourceWord": "cat",
          "required": ["dog"],
          "bonus": [],
          "tooCommon": [],
          "difficulty": "beginner",
          "levelNumber": 1
        }
      ]
      ''';
      final report = validateLevelBlob(jsonBlob, language: 'en');
      expect(report.errors, isNotEmpty);
      expect(report.errors.first, contains('dog'));
    });

    test('fails on unknown difficulty', () {
      const jsonBlob = '''
      [{"sourceWord":"cat","required":["at"],"bonus":[],"tooCommon":[],"difficulty":"legendary","levelNumber":1}]
      ''';
      final report = validateLevelBlob(jsonBlob, language: 'en');
      expect(report.errors.any((e) => e.contains('difficulty')), isTrue);
    });

    test('fails on duplicate levelNumber within same difficulty', () {
      const jsonBlob = '''
      [
        {"sourceWord":"cat","required":["at"],"bonus":[],"tooCommon":[],"difficulty":"beginner","levelNumber":1},
        {"sourceWord":"dog","required":["do"],"bonus":[],"tooCommon":[],"difficulty":"beginner","levelNumber":1}
      ]
      ''';
      final report = validateLevelBlob(jsonBlob, language: 'en');
      expect(report.errors.any((e) => e.contains('duplicate')), isTrue);
    });

    test('warns on required word shorter than 5 without failing', () {
      const jsonBlob = '''
      [{"sourceWord":"cat","required":["at","cat"],"bonus":[],"tooCommon":[],"difficulty":"beginner","levelNumber":1}]
      ''';
      final report = validateLevelBlob(jsonBlob, language: 'en');
      expect(report.errors, isEmpty);
      expect(report.warnings, isNotEmpty);
    });
  });
}
```

- [ ] **Step 2: Run**

`flutter test test/tool/validate_levels_test.dart -v` — expect FAIL (file doesn't exist).

- [ ] **Step 3: Implement**

Create `tool/validate_levels.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:slova_iz_slova/engine/game_engine.dart';

class ValidationReport {
  final List<String> errors;
  final List<String> warnings;
  ValidationReport(this.errors, this.warnings);
  bool get ok => errors.isEmpty;
}

const _difficulties = {'beginner', 'easy', 'medium', 'hard', 'expert'};

ValidationReport validateLevelBlob(String jsonBlob, {required String language}) {
  final errors = <String>[];
  final warnings = <String>[];
  final decoded = jsonDecode(jsonBlob) as List<dynamic>;
  final seenKeys = <String, int>{}; // "$difficulty:$levelNumber" -> index

  for (var i = 0; i < decoded.length; i++) {
    final lvl = decoded[i] as Map<String, dynamic>;
    final tag = '[$language idx=$i sourceWord=${lvl['sourceWord']}]';
    final source = lvl['sourceWord'] as String?;
    if (source == null || source.isEmpty) {
      errors.add('$tag missing sourceWord'); continue;
    }
    final required = List<String>.from(lvl['required'] ?? []);
    final bonus = List<String>.from(lvl['bonus'] ?? []);
    final tooCommon = List<String>.from(lvl['tooCommon'] ?? []);
    final difficulty = lvl['difficulty'] as String?;
    final levelNumber = lvl['levelNumber'] as int?;

    if (difficulty == null || !_difficulties.contains(difficulty)) {
      errors.add('$tag invalid difficulty "$difficulty"');
    }
    if (levelNumber == null || levelNumber < 1) {
      errors.add('$tag invalid levelNumber "$levelNumber"');
    } else if (difficulty != null) {
      final key = '$difficulty:$levelNumber';
      if (seenKeys.containsKey(key)) {
        errors.add('$tag duplicate levelNumber $levelNumber in bucket $difficulty (also at idx=${seenKeys[key]})');
      }
      seenKeys[key] = i;
    }

    for (final w in required) {
      if (!GameEngine.canFormWord(w, source)) {
        errors.add('$tag required "$w" not formable from "$source"');
      }
      if (w.length < 5) warnings.add('$tag required "$w" is unusually short');
      if (w.length > 15) warnings.add('$tag required "$w" is unusually long');
    }
    for (final w in bonus) {
      if (!GameEngine.canFormWord(w, source)) {
        errors.add('$tag bonus "$w" not formable from "$source"');
      }
      if (required.contains(w)) {
        errors.add('$tag "$w" appears in both required and bonus');
      }
      if (w.length > 8) warnings.add('$tag bonus "$w" is unusually long');
    }
    for (final w in tooCommon) {
      if (!GameEngine.canFormWord(w, source)) {
        errors.add('$tag tooCommon "$w" not formable from "$source"');
      }
      if (required.contains(w) || bonus.contains(w)) {
        errors.add('$tag "$w" appears in tooCommon and required/bonus');
      }
    }

    if (lvl['tooCommon'] == null) {
      warnings.add('$tag missing tooCommon array');
    }
  }

  return ValidationReport(errors, warnings);
}

Future<void> main(List<String> args) async {
  int anyError = 0;
  for (final lang in ['ru', 'en']) {
    final path = 'assets/data/${lang == 'ru' ? 'russian' : 'english'}_levels.json';
    final blob = await File(path).readAsString();
    final report = validateLevelBlob(blob, language: lang);
    for (final w in report.warnings) {
      stderr.writeln('WARN  $w');
    }
    for (final e in report.errors) {
      stderr.writeln('ERROR $e');
    }
    stdout.writeln('$lang: ${report.errors.length} errors, ${report.warnings.length} warnings');
    if (report.errors.isNotEmpty) anyError = 1;
  }
  exit(anyError);
}
```

- [ ] **Step 4: Run**

`flutter test test/tool/validate_levels_test.dart -v` — expect GREEN.
`dart run tool/validate_levels.dart` — expect 0 errors against v2's existing `assets/data/*.json` (both files already pass the generator's invariants, which are stricter than the loader's).

- [ ] **Step 5: Write `tool/README.md`**

Document the validator usage, soft/hard failure policy, and point at `tools/level_generator/` for the upstream generator pipeline.

- [ ] **Step 6: Commit**

```
git add tool/validate_levels.dart tool/README.md test/tool/validate_levels_test.dart
git commit -m "feat(tool): add Dart level validator for loader-side invariants"
```

---

## Task 2: Content handoff brief for Kat — `docs/v2/CONTENT_HANDOFF.md`

**Files:**
- Create: `docs/v2/CONTENT_HANDOFF.md`

- [ ] **Step 1: Write the handoff brief**

The brief contains:

1. **Distribution gap table** (reproduce the table from the top of this phase plan: 16 beginner / 11 easy / 14 medium / 19 hard / 17 expert for RU; 15/13/15/17/20 for EN).
2. **Source-word selection criteria**:
   - 7–11 letters.
   - Common enough that mid-frequency players recognise the stem word.
   - Generates ≥ 8 required words and ≥ 2 bonus words under the target-bucket profile in `PROFILES`.
   - Avoids overlap with the 43 existing source words in `assets/data/*.json`.
3. **Calibrator workflow** (copy/adapt from DECISIONS.md D10 & D16):
   - Run `python tools/level_generator/calibrate_ru.py --source <word>` (or `_en.py` for English).
   - Review the suggested profile; accept or override via `manual_assignments_{ru,en}.json`.
   - Inspect the near-miss list for candidates to manually promote to required.
   - Re-run `generate_{ru,en}.py` to regenerate the level JSON.
4. **Commit etiquette**:
   - One commit per batch of ≤ 10 new source words, titled `content(lang): add N <difficulty> levels`.
   - Include the generator command line and calibrator output snippet in the commit message.
   - Do not edit `generate_*.py` or `PROFILES` without an accompanying DECISIONS.md entry.
5. **Acceptance**:
   - `dart run tool/validate_levels.dart` exits 0.
   - `flutter test` passes.
   - New levels show up correctly in the level picker.

- [ ] **Step 2: Commit**

```
git add docs/v2/CONTENT_HANDOFF.md
git commit -m "docs: content handoff brief for v1.1 level expansion"
```

---

## Task 3: `docs/LEVEL_AUTHORING.md` — permanent authoring guide

**Files:**
- Create: `docs/LEVEL_AUTHORING.md`

This guide is broader than the v1.1-specific handoff — it documents the level-authoring workflow for the project going forward, not just the 100-per-lang push. Target audience: any future content author who inherits Kat's pipeline.

- [ ] **Step 1: Write the guide**

Sections:

1. **Pipeline overview** — generator → calibrator → manual overrides → validator → app.
2. **Difficulty rubric** (copy from this plan).
3. **PROFILES reference** — link to `tools/level_generator/generate_{ru,en}.py`; describe each profile parameter.
4. **When to rebuild the corpus** — frequency-list sources, when re-fetching is needed.
5. **Manual assignments** — when to override a calibrator suggestion, how to document in the JSON.
6. **Validator usage** — `dart run tool/validate_levels.dart`.
7. **CI** — the `.github/workflows/content-validate.yml` gate and how to debug failures.
8. **Known pitfalls** — ё vs е distinctness, language-specific function-word filters, hunspell dictionary updates.

- [ ] **Step 2: Commit**

```
git add docs/LEVEL_AUTHORING.md
git commit -m "docs: permanent level-authoring guide"
```

---

## Task 4: CI content-validator — `.github/workflows/content-validate.yml`

**Files:**
- Create: `.github/workflows/content-validate.yml`

- [ ] **Step 1: Write the workflow**

Triggers on PR + push to any branch. Runs `dart run tool/validate_levels.dart`. Fails the build on non-zero exit.

```yaml
name: content-validate
on:
  pull_request:
    paths:
      - 'assets/data/**'
      - 'tool/validate_levels.dart'
      - 'lib/engine/game_engine.dart'
  push:
    branches: [v2, main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.6'
          channel: stable
      - run: flutter pub get
      - run: dart run tool/validate_levels.dart
```

- [ ] **Step 2: Commit**

```
git add .github/workflows/content-validate.yml
git commit -m "ci: gate PRs on level-data validator"
```

Note: this is one of two CI workflows Phase 9 also references. Coordinate with the main CI workflow so they don't overlap; this one is level-data-specific and can coexist.

---

## Task 5: `LevelLoader` v2 test coverage

**Files:**
- Create: `test/engine/level_loader_v2_test.dart`

Covers:
- Difficulty enum parsing (each string → correct enum).
- Null / unknown difficulty → `LevelDifficulty.beginner` default.
- tooCommon array propagation to `GameLevel.tooCommon`.
- Unformable words silently dropped at load (the existing safety net).
- `levelCount(mode)` returns correct count.
- `generateLevel(levelNumber, mode)` for in-range levels returns a valid `GameLevel` with `sourceWord == sourceWord` (identity check).

Note: out-of-range throw behaviour is covered by Phase 3 Task 1 (`LevelNotFoundException`). Do not duplicate that here.

- [ ] **Step 1: Write failing tests** with asset-bundle stub.

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slova_iz_slova/engine/level_loader.dart';
import 'package:slova_iz_slova/models/game_state.dart';
import 'package:slova_iz_slova/models/language_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fixture = '''
  [
    {"sourceWord":"strawberry","required":["berry","straw"],"bonus":["bay"],"tooCommon":["a"],"difficulty":"easy","levelNumber":1},
    {"sourceWord":"orchestra","required":["chest","rose"],"bonus":[],"tooCommon":[],"difficulty":"bogus","levelNumber":2}
  ]
  ''';

  setUp(() {
    ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'assets/data/english_levels.json') {
          return ByteData.sublistView(Uint8List.fromList(utf8.encode(fixture)));
        }
        return null;
      },
    );
    LevelLoader.resetForTest();
  });

  test('parses difficulty string into enum', () async {
    final lvl = await LevelLoader.generateLevel(1, LanguageMode.english);
    expect(lvl.difficulty, LevelDifficulty.easy);
  });

  test('unknown difficulty defaults to beginner', () async {
    final lvl = await LevelLoader.generateLevel(2, LanguageMode.english);
    expect(lvl.difficulty, LevelDifficulty.beginner);
  });

  test('tooCommon array propagates to GameLevel', () async {
    final lvl = await LevelLoader.generateLevel(1, LanguageMode.english);
    expect(lvl.tooCommon, contains('a'));
  });

  test('levelCount returns length of the loaded array', () async {
    expect(await LevelLoader.levelCount(LanguageMode.english), 2);
  });
}
```

- [ ] **Step 2: Run + confirm red**

`flutter test test/engine/level_loader_v2_test.dart -v` — expect FAIL until `LevelLoader.resetForTest()` exists (it may already; if missing add a trivial `@visibleForTesting static void resetForTest() { _cache.clear(); }` on `LevelLoader`).

- [ ] **Step 3: Implement**

If `resetForTest()` is missing, add it. Otherwise no code change — the tests document existing v2 behaviour.

- [ ] **Step 4: Run + confirm green.**

- [ ] **Step 5: Commit**

```
git add test/engine/level_loader_v2_test.dart
git commit -m "test(loader): cover v2 LevelLoader invariants"
```

---

## Task 6: Final verification (phase gate)

**Only runs after Kat's content arrives** and the validator + CI are green on the combined output.

- [ ] **Step 1: Run validator**

`dart run tool/validate_levels.dart` — expect 0 errors across both files.

- [ ] **Step 2: Verify distribution**

Run a one-off script or manual grep to confirm the target distribution is met:

```bash
for lang in russian english; do
  echo "=== $lang ==="
  for diff in beginner easy medium hard expert; do
    count=$(grep -oE "\"difficulty\"\s*:\s*\"$diff\"" assets/data/${lang}_levels.json | wc -l)
    echo "  $diff: $count / 20"
  done
done
```

Expected: each bucket shows 20/20 for each language.

- [ ] **Step 3: Smoke test on device**

Launch the game in both languages. Play at least one level from each difficulty bucket. Confirm:
- Level picker shows 100 levels per language with correct difficulty pips (Phase 3 dependency).
- Library-complete screen fires after completing level 100 (Phase 3 dependency).
- No crashes, no silently dropped words (check via `debugPrint` logs).

- [ ] **Step 4: Tag + commit final**

```
git tag phase/7/complete
```

No code commit here — the milestone is Kat's content merging into v2.

---

## Out of scope

- Level-picker UI for difficulty pips — owned by Phase 3 (`lib/widgets/level_picker_tile.dart`).
- Achievements based on difficulty completion (e.g. "complete 5 expert levels") — owned by Phase 3 achievements engine.
- Per-profile (P1–P10) expansion beyond the 5-bucket enum — deferred until DECISIONS.md D16's P1–P10 roadmap is ready to ship.
- Generator modifications or new language support — Kat's domain, separate project scope.

---

## Dependencies

- **Phase 3** must land before Task 6 can fully verify (needs level picker + library-complete screen).
- **Phase 9** CI setup overlaps with Task 4 — coordinate to avoid duplicate workflows.
- **Kat's content delivery** must land before Task 6. If Kat's work is delayed, Tasks 1–5 can still ship (infrastructure only) and Task 6 stays open until content arrives.

---

## Risk register

| Risk | Mitigation |
|---|---|
| Kat's output fails the Dart validator (divergent schema assumptions) | Task 4 CI gates it on every PR. Loop back to update either the validator or the generator based on root cause. |
| 100-per-lang is more than Kat can deliver in one window | Accept a phased rollout: ship at 50/lang first, lift to 100/lang in v1.2. Level picker handles both sizes without code changes. |
| Generator regressions break existing JSON (if Kat edits `PROFILES`) | DECISIONS.md D10/D16 + CI validator. If `PROFILES` changes, require a DECISIONS.md entry and full re-calibration. |
| Russian ё vs е inconsistency | Document in `docs/LEVEL_AUTHORING.md` (Task 3). Validator could be extended to warn — not required for v1.1. |

---

## Effort estimate

| Task | Effort |
|---|---|
| 1. Validator CLI | 2–3 h |
| 2. Content handoff brief | 1 h |
| 3. Permanent authoring guide | 1–2 h |
| 4. CI workflow | 30 min |
| 5. Loader test coverage | 1–2 h |
| 6. Final verification | 30 min (excluding Kat's content window) |
| **Total (engineering only)** | **~7 h** |

Kat's content authoring is not in this budget.

# Decision Log

Key decisions made during the initial build. Read alongside `CLAUDE.md` and `docs/FLUTTER_HANDOVER.md`.

---

## D1 — No dictionary files; validation is level-only *(superseded by D10)*

**Decision:** Word validation is purely against each level's `targetWords` list. The `russian_valid_words.txt` and `english_valid_words.txt` files from the original spec were not created.

**Why:** Dictionary files add asset weight, require loading and Set construction at startup, and enable arbitrary word entry — which is a different (harder) game design. The curated level approach gives the game designer full control over which words count. Open-ended bonus detection can be added later if needed.

**Impact:** `assets/data/*.txt` files do not exist and are not referenced in `pubspec.yaml`. `engine/dictionary.dart` from the spec was never created.

*This decision was revisited and reversed. See D10.*

---

## D2 — Runtime Google Fonts, not bundled font files

**Decision:** Use the `google_fonts` package to load PlayfairDisplay and RobotoCondensed at runtime. No `.ttf` files are bundled in `assets/fonts/`.

**Why:** Simpler development setup; no font download step before first build.

**Future action:** For production, pre-bundle the fonts to remove the network dependency on first run. See the `google_fonts` package docs for how to use cached fonts.

**Impact:** `pubspec.yaml` has no `fonts:` section. Fonts are fetched from Google CDN on first launch (cached thereafter).

---

## D3 — Built-in HapticFeedback, not flutter_vibrate

**Decision:** Use Flutter's built-in `HapticFeedback` (from `package:flutter/services.dart`). `flutter_vibrate` is not a dependency.

**Why:** `flutter_vibrate` requires additional native setup (Android permissions, iOS entitlements). Built-in `HapticFeedback` covers `.selectionClick()`, `.mediumImpact()`, and `.heavyImpact()` — sufficient for tile taps and word submissions.

**Impact:** `flutter_vibrate` is not in `pubspec.yaml`. `game_provider.dart` uses `HapticFeedback` directly.

---

## D4 — Ads scaffolding only (not implemented)

**Decision:** `google_mobile_ads` is listed in `pubspec.yaml` as a commented-out dependency. No ad placements or ad initialisation code has been written.

**Why:** Core gameplay shipped first. Ads will be added in a dedicated sprint.

**How to implement:** Uncomment the dependency, run `flutter pub get`, then add ad placements. Intended location: interstitial between levels. Banner at bottom of game screen is also an option.

---

## D6 — Score persists across levels; hints reset per level

**Decision:** `GameProvider.nextLevel()` carries `score` forward but resets `hintsRemaining` to 3.

**Why:** A cumulative score is motivating and gives players a session total to be proud of. Hints resetting per level keeps them meaningful — if they carried over, players would hoard them or run out early.

---

## D7 — All English levels audited and corrected

**Decision:** All 20 English levels were audited with a Node.js validation script before the initial push. Any word that couldn't be formed from its source word's letters was replaced with a valid alternative.

**Why:** The original Manus spec had formation errors in several levels (words requiring letters not present in the source word). These would have caused words to silently fail validation at runtime.

**Impact:** `assets/data/english_levels.json` differs from the original spec in several levels. It is the authoritative version. Do not replace it with the original spec's data.

---

## D8 — Soviet Notebook design followed as-is

**Decision:** No UI decisions deviated from the spec. The Manus handover document and React prototype were aligned, so no design comparisons were needed.

**Why:** The spec was clear and internally consistent.

---

## D9 — flutter_svg and flutter_localizations not used

**Decision:** `flutter_svg` and `flutter_localizations` (listed in the original spec's `pubspec.yaml`) were not added as dependencies.

**Why:** No SVG assets are used — the design is achieved with Flutter primitives and CustomPainter. Localisation is handled by simple `StringsRu`/`StringsEn` constant classes, which is sufficient for a two-language app without needing the full ARB/intl pipeline.

---

## D10 — Frequency-ranked dictionary as the source of truth for word lists (supersedes D1; refined by D11, D12)

**Decision:** Word lists are derived from a frequency-ranked dictionary (`assets/data/ru_freq.txt`), sourced from [hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords) (MIT licence), rather than hand-curated per level.

**Classification rules:**
- **Too common** — frequency at or above upper threshold → formable but returns "Слово слишком распространено!" and zero points; stored in `tooCommon` array in the level JSON
- **Required** — frequency in the medium band (between lower and upper thresholds), length ≤ max length → shown as blank slots
- **Bonus** — frequency below lower threshold OR length above max length → discovered dynamically, shown in bonus section
- **Excluded** — suppressed via per-level `overrides` → not surfaced to the player

**Why:** Hand-curated word lists miss valid words (e.g. "род" in level 1), require ongoing maintenance, and don't scale to 50+ levels. A frequency-ranked dictionary gives players a consistent and fair experience while keeping common words as required targets and rare/long words as rewarding discoveries.

**Thresholds:** `MIN_WORD_LENGTH` = 3 is the only global constant — a hard floor applied to all levels. All other classification thresholds (`max_length`, `freq_threshold`, `max_freq`) are set exclusively via the named difficulty profiles defined in `generate.py`. See D13.

**Source word selection:** Source words are chosen manually. Length is not fixed — current levels range from 8 to 13 letters. The selection criterion is vocabulary density: the source word should yield ~8–12 required words under the chosen difficulty profile. Words that yield too few or too many required words at any profile need replacing (see D13).

**Note on implementation:** Initially implemented as runtime classification via `engine/dictionary.dart`. Subsequently moved to an offline generator (`tools/level_generator/generate.py`) that writes pre-computed `required`, `bonus`, and `tooCommon` arrays into the level JSON — see D11. `engine/dictionary.dart` and the `ru_freq.txt` Flutter asset were removed once the generator took over all word classification.

---

## D11 — All filtering in the generator; dictionary stays raw (refines D10; further refined by D12)

**Decision:** `assets/data/ru_freq.txt` is kept raw and unmodified (Cyrillic-only entries, otherwise exactly as downloaded). All word filtering — lemmatization, POS filtering, proper noun removal, profanity blocklist, frequency thresholds, length thresholds — happens exclusively in `tools/level_generator/generate.py`.

**Why:** Keeping the dictionary raw means it never needs to be regenerated or patched when filtering rules change — only the generator needs updating. It also ensures unusual forms (interesting conjugations, place names for themed levels) can be added back via manual overrides in the level JSON without modifying the dictionary.

**Filters applied by the generator (with reasons):**
- **Hunspell quality gate** — only words recognised by the LibreOffice Russian spell-checker are admitted; rejects ~76% of pymorphy3's morphological predictions. See D12.
- **Proper nouns** (`Name`, `Surn`, `Patr`, `Geox`, `Orgn`, `Trad` tags) — removed by default because they are not general vocabulary; may be added back manually for themed levels (e.g. geography, literature)
- **Prepositions** (`PREP` POS) — removed because short prepositions feel like unearned answers; longer ones (перед, вокруг) may be added manually as bonus words where thematically fitting
- **Profanity** — removed via a manually maintained blocklist at `tools/level_generator/blocklist.txt`
- **Lemmatization** — only root forms included (nominative singular for nouns, infinitive for verbs, short form for adjectives) to avoid clutter from inflected duplicates; interesting conjugations may be added back manually

**Impact:** `ru_freq.txt` has a comment header stating it is raw. The Flutter runtime never touches the dictionary — it reads only pre-computed `required` and `bonus` arrays from the level JSON. `tools/level_generator/generate.py` is the authoritative source for all word classification logic.

---

## D12 — Hunspell as the primary word quality gate (refines D11)

**Decision:** The LibreOffice Russian hunspell dictionary (`ru_RU`) is the authoritative source of what constitutes a real Russian word. In `generate_level()`, every candidate word is checked against hunspell before any further processing. Words that fail the check are silently skipped. The frequency list (`ru_freq.txt`) is used as the iteration source and for corpus frequency lookup, but is no longer treated as a word list in its own right.

**Why:** pymorphy3's morphological prediction engine accepts ~76% noise — fragments, loanword sequences, and letter combinations that match Russian suffix patterns but are not real vocabulary. Filtering by pymorphy3's `word_is_known()` (OpenCorpora) reduced this but still admitted transliterated foreign names and unrecognised loanwords without any style marker to distinguish them from real words. The hunspell spell-checker dictionary, maintained for LibreOffice/OpenOffice, is more conservative: it targets words a native speaker would actually write, and in testing cleanly rejected the problematic residual while retaining real archaic and literary vocabulary (одр, вечор, вече, древо). The remaining noise that passes hunspell is small enough to manage via the manual blocklist.

**Why iterate over ru_freq.txt rather than the hunspell .dic directly:** The hunspell `.dic` stores full adjective forms (`-ый/-ий`) as base entries. `get_lemma()` prefers short adjective forms (краткая форма, e.g. `красив` not `красивый`) for aesthetic reasons — they are shorter and more literary. Short forms do not appear in the `.dic` and would be silently lost if we iterated over it. The frequency list contains both full and short forms as separate corpus entries, so short-form adjectives are correctly seen and pass the `get_lemma(word) == word` check. Hunspell is applied as a quality gate on top of the frequency list rather than as the iteration source.

**Dictionary source:** LibreOffice/dictionaries `ru_RU`, available at `https://github.com/LibreOffice/dictionaries/tree/master/ru_RU`. Licence: LGPL v3 / MPL 1.1 / GPL v3. The `.dic` and `.aff` files are installed locally via pyenchant and are not bundled in this repository.

**Impact:** The `blocklist.txt` noise section shrank from ~50 entries with 3 programmatic RULE directives to 6 manually curated entries covering only the residual cases hunspell cannot distinguish from real vocabulary. The profanity section shrank from 30 entries to 6 (the remainder are rejected by hunspell directly).

---

## D13 — Five difficulty profiles for required-word count targeting (refines D10)

**Decision:** Five named difficulty profiles replace ad-hoc per-level threshold overrides. Each profile is a fixed combination of `freq_threshold` (ft), `max_freq` (mf), and `max_length` (ml):

| Profile | ft | mf | ml | Notes |
|---|---|---|---|---|
| P1_BEGINNER | 5000 | 20000 | 4 | Short, very common words only |
| P2_EASY | 2000 | 10000 | 5 | Common vocabulary, up to 5 letters |
| P3_MEDIUM | 1000 | 20000 | 5 | Broader common words, up to 5 letters |
| P4_HARD | 500 | 10000 | 6 | Rarer words, up to 6 letters |
| P5_EXPERT | 200 | 5000 | 6 | Rare/literary vocabulary, up to 6 letters |

Each level function is assigned to the profile that gives it the closest required-word count to 10, verified by threshold analysis across all 23 source words. Target range is 8–12 required words.

**Why:** No single threshold set produces ~10 required words for every source word — vocabulary density varies too much between them. Named profiles make assignments legible (each level function comments its profile and expected count) and make future source word selection principled: generate a candidate at all 5 profiles, pick the source word whose profile gives the desired difficulty, assign that profile.

**Source words needing replacement:** Two levels cannot reach 8–12 required words at any profile: `правительство` (minimum ~14 at P1_BEGINNER — letters form too many common words) and `территория` (maximum ~5 at P5_EXPERT — insufficient formable vocabulary). Both are flagged with TODO comments in `generate.py` and use a temporary profile pending replacement.

**Impact:** `PROFILES` dict added to `generate.py`. All 23 level functions call `generate_level(..., **PROFILES['Pn_NAME'])`. Previous ad-hoc overrides (`max_freq=5000` on level 10, `freq_threshold=200` on levels 12, 16, 19) replaced with the appropriate profile calls. `MIN_WORD_LENGTH` = 3 remains the only global threshold constant; all other threshold parameters are now set exclusively through profiles.

---

## D14 — Replication guide: building an English generator with the same constraints *(TODO — remove once English generator is built and english_levels.json is regenerated)*

**Context:** The current `tools/level_generator/generate.py` is Russian-only (uses pymorphy3 for morphology and the hermitdave Russian frequency list). The 20 English levels in `assets/data/english_levels.json` are hand-crafted (see D7). This entry documents how to build a generator-based English equivalent following the same architecture and constraints. **Delete this entry once the English generator exists and `english_levels.json` is produced by it.**

**Step 1 — English frequency list**

Download the hermitdave English frequency list (same project, same MIT licence):

```
https://github.com/hermitdave/FrequencyWords/blob/master/content/2018/en/en_50k.txt
```

Place at `assets/data/en_freq.txt`. Format is identical to `ru_freq.txt`: one `word count` pair per line. Load with the existing `load_freq()` function (no changes needed).

**Step 2 — English morphology (replaces pymorphy3)**

pymorphy3 is Russian-only. For English lemmatization install two packages:

```
pip install nltk lemminflect
```

Then bootstrap NLTK once:

```python
import nltk
nltk.download('wordnet')
nltk.download('averaged_perceptron_tagger_eng')
```

Replace the Russian `get_lemma()` function with an English equivalent:

```python
from nltk.stem import WordNetLemmatizer
from nltk import pos_tag

_lemmatizer = WordNetLemmatizer()

_POS_MAP = {'NN': 'n', 'VB': 'v', 'JJ': 'a', 'RB': 'r'}

def get_lemma_en(word):
    """Return the lemma of word, or None if it is not in base/lemma form."""
    tag = pos_tag([word])[0][1][:2]
    pos = _POS_MAP.get(tag, 'n')
    lemma = _lemmatizer.lemmatize(word.lower(), pos)
    return lemma if lemma == word.lower() else None
```

**Step 3 — English hunspell dictionary**

Install the LibreOffice en_US dictionary via pyenchant:

```
pip install pyenchant
```

pyenchant ships `en_US` by default on most systems. If not, download `en_US.dic` and `en_US.aff` from `https://github.com/LibreOffice/dictionaries/tree/master/en` and point pyenchant at them. Replace `enchant.Dict('ru_RU')` with `enchant.Dict('en_US')` in the generator.

**Step 4 — Adapting generate_level() for English**

The classification logic, PROFILES, PROFILE_DIFFICULTY, and canFormWord() are all language-agnostic — carry them over unchanged. The only changes to `generate_level()` are:

1. Replace `morph.parse(word)[0]` with the English lemmatizer call
2. Remove the Russian-specific proper noun / preposition tag filters; replace with English equivalents (NLTK tags `NNP`/`NNPS` for proper nouns; `IN` for prepositions)
3. The `get_lemma(word) == word` guard (keeps only base forms) works the same way

**Step 5 — Profile calibration for English**

Run the 5 profiles against candidate source words and record required-word counts. English vocabulary density differs from Russian — the P1–P5 thresholds may need recalibrating. The same methodology applies: pick the profile that puts a source word in the 8–12 required word target range. Recalibrate by adjusting `freq_threshold` / `max_freq` / `max_length` until the distribution looks right across a sample of 10+ source words.

**Step 6 — Level function naming and output**

Level function names follow the same `level_{tier}_{index}` convention. The `main()` function is unchanged — it stamps `difficulty` and `levelNumber` from `profile` automatically. Set `OUTPUT_FILE` to `assets/data/english_levels.json`.

**Note on existing English levels:** `assets/data/english_levels.json` currently contains 20 hand-crafted levels (see D7). Running the English generator will overwrite this file. Retain a backup or migrate the hand-crafted source words into generator-style level functions before running.

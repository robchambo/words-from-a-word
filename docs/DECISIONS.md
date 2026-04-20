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

## D13 — Five difficulty profiles (refines D10; further refined by D16)

**Decision:** Five named difficulty profiles replace ad-hoc per-level threshold overrides. Each profile is a fixed combination of `freq_threshold` (ft), `min_length` (min_l), and `max_length` (max_l):

| Profile | ft | min_l | max_l | Notes |
|---|---|---|---|---|
| P1_BEGINNER (RU) | 4000 | 3 | 4 | Top 2% of Russian vocab |
| P2_EASY (RU) | 1300 | 3 | 5 | Top 5% of Russian vocab |
| P3_MEDIUM (RU) | 470 | 3 | 5 | Top 10% of Russian vocab |
| P4_HARD (RU) | 240 | 4 | 6 | Top 15% of Russian vocab |
| P5_EXPERT (RU) | 144 | 4 | 6 | Top 20% of Russian vocab |
| P1_BEGINNER (EN) | 84000 | 3 | 4 | Top 1% of English vocab |
| P2_EASY (EN) | 10000 | 3 | 4 | Top 5% of English vocab |
| P3_MEDIUM (EN) | 3100 | 3 | 5 | Top 10% of English vocab |
| P4_HARD (EN) | 1430 | 4 | 5 | Top 15% of English vocab |
| P5_EXPERT (EN) | 780 | 4 | 6 | Top 20% of English vocab |

Classification: a word is **required** if `min_length ≤ len ≤ max_length` and `count ≥ freq_threshold`; otherwise it is **bonus** (too short, too long, or too rare). Words below `MIN_WORD_LENGTH = 3` are silently dropped. `tooCommon` is exclusively function words via POS filter (see D15) — there is no frequency-based upper ceiling on required words.

**Why:** No single threshold set works for every source word — vocabulary density varies too much. Named profiles make assignments legible. Difficulty comes from source word selection (see D16), not per-word frequency caps.

**Source words needing replacement:** `правительство` and `территория` (Russian), `thunderstorm` and `playground` (English) cannot reach 7–13 required words at any profile and are flagged with TODO comments in the generator files.

**Impact:** `PROFILES` dict in both generators. All level functions call `make_level(..., 'Pn_NAME', ...)`. `MIN_WORD_LENGTH = 3` remains the global absolute floor; all other threshold parameters are set exclusively through profiles.

---

## D14 — Language-specific generator decisions (Russian: pymorphy3; English: spaCy)

Both generators share the same architecture (D10–D13): frequency list as iteration source, hunspell as quality gate, difficulty profiles, `make_level()` helper, `level_{tier}_{index}` naming, `main()` stamping `difficulty` and `levelNumber`. This entry documents the decisions that differ by language.

---

### Russian-specific decisions

**Morphology library — pymorphy3**

pymorphy3 (OpenCorpora) is the standard Russian morphological analyser. It produces a canonical lemma via `get_lemma()` which returns: nominative singular for nouns, infinitive for verbs, and short masculine singular (краткая форма) for adjectives. Short adjective forms are preferred over full forms (`красив` not `красивый`) for aesthetic reasons — they are shorter and more literary, fitting the Soviet Notebook theme.

**Why iterate ru_freq.txt rather than the hunspell .dic:** The hunspell `.dic` stores full adjective forms (`-ый/-ий`) as base entries. Short adjective forms (краткая форма, e.g. `красив`) do not appear in the `.dic` and would be silently lost if we iterated over it. The frequency list contains both full and short forms as separate corpus entries, so short-form adjectives are correctly seen and pass the `get_lemma(word) == word` check. Hunspell is applied as a quality gate on top of the frequency list rather than as the iteration source.

**POS filters:** Proper nouns (`Name`, `Surn`, `Patr`, `Geox`, `Orgn`, `Trad` grammeme tags) and prepositions (`PREP` POS) are removed. Short prepositions (в, на, по) feel like unearned answers; longer ones may be added manually as bonus words.

**Profile threshold values:** See D13. The Russian frequency list uses raw corpus counts from the hermitdave OpenSubtitles 2018 dataset. The values (ft=200–5000, mf=5000–20000) were calibrated against all 23 Russian source words.

**Calibration tool:** `tools/level_generator/calibrate.py` — run with `py calibrate.py` to score all 23 source words against all 5 profiles in one pass. Re-run when adding source words or adjusting profiles.

---

### English-specific decisions

**Morphology library — spaCy `en_core_web_sm` *(originally NLTK; see addendum below)***

pymorphy3 is Russian-only. The English generator uses spaCy's `en_core_web_sm` model for both lemmatization and POS tagging. `get_lemma_en(word)` mirrors `get_lemma(word)` in the Russian generator: it returns the canonical base form, and `generate_level()` skips any word where `get_lemma_en(word) != word`.

**POS filters:** Proper nouns (`PROPN`) are dropped entirely. Function words (`ADP`, `PRON`, `CCONJ`, `SCONJ`, `DET`, `INTJ`, `PART`) are routed to `tooCommon` — see D15.

**Why spaCy over NLTK:** NLTK's perceptron tagger was the original choice (convenience — low setup barrier, familiar API). Its critical limitation: it was trained on full sentences and defaults to `NN` on isolated words, meaning `PROPER_NOUN_TAGS` and `PREPOSITION_TAGS` filters almost never fired in practice. The hunspell gate and manual blocklist were compensating for a tool deficiency. spaCy tags isolated words reliably using Universal Dependencies, making the function word filter work as designed and shrinking `function_words_en.txt` to a true edge-case safety net rather than a manual patch list.

**Why spaCy over stanza:** stanza's neural models are more accurate on benchmarks but significantly slower (minutes vs. seconds for the global vocabulary cache build in `calibrate_en.py`). For the English generator's use case — offline batch processing of ~20 source words — spaCy's accuracy is sufficient and the speed difference matters for development iteration.

**Frequency list:** `tools/level_generator/en_freq.txt` — hermitdave English OpenSubtitles 2018 full list (same project as Russian, MIT licence). The English loader deduplicates by keeping the highest-count entry if a word appears twice (an edge case absent in the Russian list).

**Profile threshold values:** English vocabulary density is significantly higher than Russian — the same raw thresholds would yield far too many required words per level. Profiles were recalibrated for English (ft=800–80000, mf=15000–500000 vs. Russian's ft=200–5000, mf=5000–20000). The calibration methodology is identical: sweep all profiles against all source words, assign each word to the profile closest to 10 required words. 15 of 20 English source words land in the 7–13 band; 5 are flagged with TODO comments pending source-word replacement.

**Calibration tool:** `tools/level_generator/calibrate_en.py` — run with `python calibrate_en.py` to score all source words against all 5 profiles. Re-run when adding source words, adjusting profiles, or replacing TODO source words.

**Bootstrap:** Run `python bootstrap.py` once after `pip install -r requirements.txt` to download the spaCy `en_core_web_sm` model and verify both hunspell dictionaries are available.

---

## D15 — Function word POS filter as the sole tooCommon axis (refines D10, D13)

**Decision:** Both generators route grammatical function words to `tooCommon` based on POS tag. `tooCommon` is determined exclusively by POS — there is no frequency-based upper ceiling. Words in `FUNCTION_WORD_POS` (or listed in `function_words_*.txt` for mislabelled edge cases) → `tooCommon`; all other content words above `freq_threshold` go to `required` or `bonus` based on length.

Russian `FUNCTION_WORD_POS`: `{'PREP', 'NPRO', 'CONJ', 'PRCL', 'INTJ', 'PRED'}`
English `FUNCTION_WORD_POS`: `{'ADP', 'PRON', 'CCONJ', 'SCONJ', 'DET', 'INTJ', 'PART'}`

**Why POS-only, no frequency ceiling:** A previous design used `max_freq` as a second tooCommon axis, filtering high-frequency content words like год, утро, fly, back. This was removed because: (a) it made good game words like год and back unreachable even as bonus, (b) the threshold was arbitrary and corpus-biased (subtitle corpora over-represent conversational vocabulary), and (c) difficulty is now handled by source word selection and corpus-anchored `freq_threshold` values (see D16) rather than per-word frequency caps. A pronoun is a function word regardless of frequency; a content word is a valid game target regardless of how common it is.

**Why a supplementary text file:** pymorphy3 and spaCy both produce occasional POS mislabels on isolated words. `function_words_ru.txt` and `function_words_en.txt` are safety-net lists for these edge cases. They are intentionally minimal — most function words are correctly caught by POS.

**Impact:** `max_freq` removed from `PROFILES`. `tooCommon` in generated JSON now contains only function words. Content words previously filtered as tooCommon (год, утро, fly, back, etc.) now appear in `required` or `bonus` at appropriate profiles.

---

## D16 — Median-frequency difficulty calibration; corpus-anchored thresholds (refines D13)

**Decision:** Profile difficulty is calibrated by the **median corpus frequency of formable content words within the profile's length window** for a given source word, not by counting required words. `freq_threshold` values are anchored to fixed percentiles of the global valid-lemma vocabulary rather than tuned to hit a target word count.

**Percentile anchors:**

| Profile | Percentile | Rationale |
|---|---|---|
| P1_BEGINNER | top 1% (EN) / top 2% (RU) | Household vocabulary — words used without thinking |
| P2_EASY | top 5% | Everyday educated vocabulary |
| P3_MEDIUM | top 10% | Words appearing regularly in books and news |
| P4_HARD | top 15% | Extended vocabulary — rewards wide reading |
| P5_EXPERT | top 20% | Rare/literary — genuinely challenging |

**Why the percentiles differ between languages:** English has far more short, extremely high-frequency content words (run, eat, end, turn, etc.) that inflate required counts at P1_BEGINNER. Using top 2% for English P1 (as in Russian) produces 18–28 required words for rich source words like adventure or waterfall. Russian's top-frequency vocabulary is sparser in short formable forms — top 2% produces 8–11 required words, while top 1% would collapse counts to 3–6. The percentile anchors are therefore set independently per language, choosing the tightest cutoff that keeps most source words in the 7–13 required word band.

**Why median, not required count:** Required word count is a function of both the source word AND the profile thresholds — it changes every time thresholds are adjusted. The median frequency of the formable word set is an intrinsic property of the source word at a given profile: a source word whose formable words are all very common will have a high median regardless of threshold tuning. This makes the median a stable difficulty signal for source word selection and profile assignment.

**How difficulty is set in practice:**
1. `freq_threshold` anchors are derived from percentiles of the global vocabulary (recomputed by `calibrate_*.py` Phase 1 if the frequency list changes).
2. `min_length` and `max_length` remain design choices — they define the required-word length window and are tuned per profile to keep required counts in the 5–15 eligible band.
3. `calibrate_*.py` Phase 2 finds the **eligible profiles** for each source word — those where required count falls in [5, 15]. Words with only one eligible profile are unambiguously assigned. Words with multiple eligible profiles are given a **suggested** assignment by log-scale median distance to targets derived from unambiguous and manually anchored words.
4. **Profile assignments are manually confirmed** by editing `manual_assignments_*.json`. The calibrator reads this file on every run and never overwrites it. Manual assignments take precedence; the calibrator warns if a previously confirmed assignment drifts out of the eligible range.
5. If no profile produces 5–15 required words, the source word needs replacement rather than threshold adjustment.

**`freq_threshold` vs. suggestion targets — key distinction:** `freq_threshold` is the per-word floor that determines which words are *required* (vs. bonus). Suggestion targets are the expected median frequency of required words for a given profile tier — they are on the same numeric scale but describe different things. A source word may have its required words' median well above `freq_threshold`; the suggestion target tells the calibrator which profile tier that median best matches.

**Relationship to D15:** With `max_freq` removed, `tooCommon` is now POS-only. The freq_threshold lower bound still determines required vs. bonus, but there is no upper bound — common content words (год, fly, back) are now valid required or bonus words at appropriate profiles rather than being silently suppressed.

**Impact:** `max_freq` removed from `PROFILES` in both generators. `min_length` added as a per-profile parameter (previously a global constant). `calibrate_*.py` rewritten with `get_required()`, `median_of()`, `compute_targets()`, `suggest_profile()`, and `compute_threshold_at_percentile()`. Manual assignments stored in `manual_assignments_*.json`. Phase 1 output shows corpus-anchored threshold verification (✓ when PROFILES match the percentile cutoff).

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

## D13 — Five difficulty profiles *(SUPERSEDED by D16)*

The original five-profile design and its threshold values are preserved here for history only. The current profile parameters, design rationale, and full P1–P10 roadmap are in **D16**. Do not use the values in this entry.

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

## D16 — Profile system design: P1–P10 roadmap, corpus, calibration (supersedes D13)

### Difficulty design principles

**Length is the primary difficulty axis.** Each profile defines a required-word length window (min_length–max_length). As profiles get harder, the window shifts upward: players must find longer words. **Frequency threshold is secondary** — it prevents truly obscure words from appearing as required, and loosens as length increases because longer words are naturally rarer in any corpus even when well-known.

**Frequency thresholds are anchored to corpus percentiles**, not raw counts. Both languages share the same percentile spine; the raw numbers differ because the corpora have different densities. Percentiles are the stable anchor across any future corpus swap.

**The same source word can appear at multiple profiles.** A 12-letter source word at P1 requires only its very common 3–4 letter subwords; at P5 it requires its 5–8 letter subwords. This is a future design avenue for "level variants."

---

### Frequency corpus

Both languages use **hermitdave/FrequencyWords** (OpenSubtitles 2018, MIT licence) for both Russian and English. This is a TV/film subtitle corpus.

**Known bias:** subtitle corpora over-represent conversational vocabulary and under-represent concrete everyday nouns, academic words, and formal registers. A word like блокнот (notepad) may have low subtitle frequency despite being universally known. **Mitigation:** percentile anchoring means the system is self-correcting — thresholds track the corpus distribution rather than absolute counts. Words outside required still appear as bonus. The bias is most significant at P6–P10 (top 25–52% of vocab) where the tail diverges more; this is noted as a known limitation for when those profiles are built.

**Why not switch to a more balanced corpus (e.g. Lyashevskaya & Sharoff for Russian, COCA for English):** The hermitdave MIT licence is unambiguous for commercial use. Academic corpora carry non-commercial or unclear licence terms. The corpus is gamewide and permanent — switching mid-development would invalidate all manual assignments and calibrated thresholds. The subtitle bias at P1–P5 (top 2–12% of vocab) is modest; the top vocabulary is similar across any serious Russian or English corpus.

---

### Implemented profiles: P1–P5

Both languages use the same percentile spine. Raw `freq_threshold` values are what those percentiles happen to be in each corpus.

| Profile | Req len | Percentile | RU ft≥ | EN ft≥ |
|---------|---------|-----------|--------|--------|
| P1_BEGINNER | 3–4 | top 2% | 3,925 | 37,844 |
| P2_EASY | 3–5 | top 3% | 2,395 | 21,042 |
| P3_MEDIUM | 4–6 | top 5% | 1,313 | 9,997 |
| P4_HARD | 5–7 | top 8% | 669 | 4,730 |
| P5_EXPERT | 5–8 | top 12% | 351 | 2,179 |

Example required words per tier (Russian / English):

| Profile | Russian | English |
|---------|---------|---------|
| P1 3–4 | год, рот, есть, пока | can, have, just, here |
| P2 3–5 | место, время, много | about, think, never |
| P3 4–6 | только, сейчас, почему | really, people, always |
| P4 5–7 | сказать, сегодня, никогда | believe, morning, already |
| P5 5–8 | говорить, проблема, получить | remember, actually, together |

---

### P6–P10 roadmap (not yet implemented)

The full 10-profile design extends the same spine. P6–P10 are documented here for when they are built; parameters are not in the generators yet.

| Profile | Req len | Percentile | RU ft≥ | EN ft≥ | RU src len | EN src len |
|---------|---------|-----------|--------|--------|------------|------------|
| P6 | 6–9 | top 18% | 174 | 982 | 11–15 | 10–14 |
| P7 | 6–10 | top 25% | 92 | 481 | 12–17 | 11–15 |
| P8 | 7–11 | top 33% | 49 | 230 | 14–19 | 12–16 |
| P9 | 7–12 | top 42% | 26 | 105 | 16–22 | 13–17 |
| P10 | 8–13 | top 52% | 13 | 44 | 18–25 | 14–18 |

P6–P10 required words are longer everyday words: говорить, нормально, интересно (P6–P7); обязательно, возможность (P8); использовать, возвращаться (P9); действительно, познакомиться (P10). English equivalents: beautiful, different (P6); information, interesting (P8); relationship, conversation (P9); investigation, unfortunately (P10).

**Subtitle bias note for P6–P10:** At top 25–52% of vocab the corpus tail diverges more from a balanced register corpus. If P6–P10 are built, the corpus decision should be revisited; however, it cannot be changed per-profile — the corpus is gamewide. A balanced alternative (Lyashevskaya & Sharoff for Russian; COCA or BNC for English) would be the recommended upgrade at that point if a compatible licence can be confirmed.

---

### Source word constraints (current)

- **Length:** 5–15 letters (nouns)
- **POS:** nouns only
- **Minimum recognisability frequency:** ~100 (words below this are likely unknown to players)
- **Required word count target:** 5–15 at the assigned profile (the eligibility band)

**Future expansion avenues (not yet implemented):**
- **Longer source words (16–25 letters):** viable for P8–P10. Russian has richer long-word vocabulary (up to 21 letters in quality-gated vocab: самосовершенствование, достопримечательность). English tops out around 16 (responsibility, extraterrestrial). Requires P6–P10 profiles to be active.
- **Adjectives:** grammatically valid but letter distributions skew toward -ский/-ный/-ный (RU) or -tion/-ing (EN) endings, which may produce repetitive required sets. Worth testing.
- **Diminutives (RU):** уменьшительно-ласкательные формы (котёнок, домик, речка) — skew shorter and simpler, potentially useful for an easier sub-profile or beginner mode.

---

### Calibration workflow

`calibrate_*.py` runs two phases:

**Phase 1 — Global vocabulary build:** Runs the full frequency list through the generator quality gate (hunspell + lemma + POS + blocklist) without any formability constraint. Results cached to `vocab_cache_*.json`. Verifies that PROFILES `freq_threshold` values match their intended percentile cutoffs (✓ within 10%).

**Phase 2 — Source word evaluation:** For each source word, finds eligible profiles (required count in [5, 15]), suggests an assignment by log-scale median distance to targets derived from anchor words, and shows the required word list per eligible profile in diff format (first profile shown in full; subsequent profiles show `+` additions and `−` removals vs. the previous eligible profile).

**Near-miss display:** Below each eligible profile's word list, the calibrator shows up to 5 formable words with freq in `[ft÷2, ft)` — words that just missed the required threshold. The `ft÷2` lower bound is one log-step below the threshold: on the Zipf distribution, halving and doubling are symmetric distances, so `ft÷2` captures the natural borderline zone without expanding into genuinely rare words. These are candidates for manual promotion to required via per-level overrides. This display also partially offsets the subtitle corpus bias: a word like блокнот or велосипед may have low subtitle frequency despite being universally known, and the near-miss list surfaces it for the level designer to consider rather than silently routing it to bonus.

**Manual assignments:** Stored in `manual_assignments_*.json`. The calibrator reads but never overwrites this file. Manual assignments take precedence over suggestions; the calibrator warns if a confirmed assignment drifts out of the eligible range after threshold changes.

**`freq_threshold` vs. suggestion targets — key distinction:** `freq_threshold` is the per-word floor determining required vs. bonus. Suggestion targets are the expected median frequency of required words for a profile tier — same numeric scale, different meaning. A source word's required-word median can sit well above `freq_threshold`; the suggestion target tells the calibrator which profile tier that median best matches.

**Impact:** `PROFILES` dict in both generators updated to new parameters. `calibrate_*.py` updated with `get_near_miss()`. `manual_assignments_*.json` stores confirmed profile assignments. D13 superseded.

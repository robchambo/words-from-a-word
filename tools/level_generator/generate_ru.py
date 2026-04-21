"""
Level generator for Слова из Слова.

For each source word, produces required, bonus, too_common, and blocked word
lists, writing the result to assets/data/russian_levels.json.

Usage:
    py generate_ru.py

Word quality gate:
    The LibreOffice Russian hunspell dictionary is the primary source of truth
    for what counts as a real Russian word. Only words that pass the hunspell
    spell-checker are admitted. See docs/DECISIONS.md D12.

    The frequency list (ru_freq.txt) serves as the iteration source AND the
    frequency lookup. Iterating over the hunspell .dic directly would be the
    architecturally purer choice, but it is not possible here: the .dic stores
    full adjective forms (-ый/-ий) as base entries, whereas get_lemma() prefers
    short forms (краткая форма) for aesthetic reasons — and short forms do not
    appear in the .dic. The frequency list contains both full and short forms as
    separate entries, so short-form adjectives are correctly seen and pass the
    get_lemma(word) == word check. Hunspell acts as the quality gate on top of
    the frequency list to reject non-words.

Word classification (applied after the quality gate):
    required — in lemma form, formable from source letters,
               min_length <= length <= max_length, frequency >= freq_threshold
    bonus    — in lemma form, formable from source letters, everything else
               (too short for required, too long, or too rare)
    too_common — function words (prepositions, pronouns, conjunctions, etc.)
    blocked  — passes quality gate but is on the noise blocklist (tracked for review)

Difficulty is determined by the median corpus frequency of the source word's
formable content words within the profile's length window. See calibrate_ru.py
and docs/DECISIONS.md D16.

Only lemma forms are processed. Non-lemma forms (inflected, conjugated,
declined) are skipped — their lemma will appear separately in the frequency
list and be processed then. This avoids redundant formability checks and
duplicate entries without needing a seen-set.

ALL filtering happens here, not in the dictionary or the Flutter runtime.
See docs/DECISIONS.md D11 for rationale.
"""

import io
import json
import os
import re
import sys
from collections import namedtuple
import enchant
import pymorphy3

# UTF-8 stdout wrap is applied inside main() so importing this module
# (e.g. from tests) does not clobber sys.stdout.

# ---------------------------------------------------------------------------
# Hard floor — minimum word length, applied to every level regardless of profile.
# ---------------------------------------------------------------------------
MIN_WORD_LENGTH = 3          # shortest word to include

# ---------------------------------------------------------------------------
# Difficulty profiles — five standard configurations (P1–P5). Profile
# assignment for each source word is determined by calibrate_ru.py.
# See docs/DECISIONS.md D16 for the full P1–P10 design rationale.
#
# Length is the primary difficulty axis; freq_threshold is secondary (it
# prevents truly obscure words from appearing as required, and drops as
# length increases since long words are naturally rarer in any corpus).
#
#   Profile        ft     min_l  max_l   Corpus percentile
#   P1_BEGINNER  3925       3      4     top  2% of valid lemmas
#   P2_EASY      2395       3      5     top  3% of valid lemmas
#   P3_MEDIUM    1313       4      6     top  5% of valid lemmas
#   P4_HARD       669       5      7     top  8% of valid lemmas
#   P5_EXPERT     351       5      8     top 12% of valid lemmas
#
# ft    = freq_threshold: words below this go to bonus (too rare for required)
# min_l = min_length:     words shorter than this go to bonus (too short)
# max_l = max_length:     words longer than this go to bonus (too long)
#
# Thresholds are anchored to percentiles of the global valid-lemma vocabulary
# (48,560 lemmas after quality gate). Re-derive via calibrate_ru.py --rebuild
# if the frequency list or quality gate changes significantly.
#
# Both languages use the same percentile spine (top 2/3/5/8/12%). The raw
# counts differ because the corpora have different densities — percentiles
# are the stable anchor; raw counts are what those percentiles happen to be.
#
# Note: MIN_WORD_LENGTH = 3 is the absolute floor applied before any profile
# filtering. Words below it are silently dropped entirely.
# ---------------------------------------------------------------------------
PROFILES = {
    'P1_BEGINNER': {'freq_threshold': 3925, 'min_length': 3, 'max_length': 4, 'percentile':  2},
    'P2_EASY':     {'freq_threshold': 2395, 'min_length': 3, 'max_length': 5, 'percentile':  3},
    'P3_MEDIUM':   {'freq_threshold': 1313, 'min_length': 4, 'max_length': 6, 'percentile':  5},
    'P4_HARD':     {'freq_threshold':  669, 'min_length': 5, 'max_length': 7, 'percentile':  8},
    'P5_EXPERT':   {'freq_threshold':  351, 'min_length': 5, 'max_length': 8, 'percentile': 12},
}

# Maps profile name → difficulty string written to the level JSON.
# These strings are parsed by LevelLoader in the Flutter app.
PROFILE_DIFFICULTY = {
    'P1_BEGINNER': 'beginner',
    'P2_EASY':     'easy',
    'P3_MEDIUM':   'medium',
    'P4_HARD':     'hard',
    'P5_EXPERT':   'expert',
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.join(SCRIPT_DIR, '..', '..')
FREQ_FILE = os.path.join(SCRIPT_DIR, 'ru_freq.txt')
BLOCKLIST_FILE = os.path.join(SCRIPT_DIR, 'blocklist_ru.txt')
FUNCTION_WORDS_FILE = os.path.join(SCRIPT_DIR, 'function_words_ru.txt')
OUTPUT_FILE = os.path.join(REPO_ROOT, 'assets', 'data', 'russian_levels.json')

# ---------------------------------------------------------------------------
# Load frequency list — used as the iteration source and frequency lookup.
# Not treated as a word list; hunspell is the quality gate (see D12).
# ---------------------------------------------------------------------------
CYRILLIC = re.compile(r'^[а-яёА-ЯЁ]+$')

def load_freq(path):
    freq = {}
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split(' ')
            if len(parts) == 2 and CYRILLIC.match(parts[0]):
                word = parts[0].lower()
                count = int(parts[1]) if parts[1].isdigit() else 0
                freq[word] = count
    print(f"Loaded {len(freq):,} words from frequency list.")
    return freq

# ---------------------------------------------------------------------------
# Load blocklist — section-aware
# ---------------------------------------------------------------------------
# Blocklists is a namedtuple so both sets travel together as a single arg.
# noise entries appear in the per-level "blocked" review output; profanity
# entries are silently dropped and never surfaced to the player.
Blocklists = namedtuple('Blocklists', ['noise', 'profanity'])

def load_blocklist(path):
    """
    Parses blocklist_ru.txt by section header.
    Returns Blocklists(noise, profanity) so generate_level can distinguish
    which blocked words to include in the per-level review output.
    """
    if not os.path.exists(path):
        return Blocklists(set(), set())
    noise = set()
    profanity = set()
    current = None
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if 'SECTION 1: NOISE' in line:
                current = noise
            elif 'SECTION 2: PROFANITY' in line:
                current = profanity
            elif line and not line.startswith('#') and current is not None:
                current.add(line.lower())
    return Blocklists(noise, profanity)

# ---------------------------------------------------------------------------
# Load function words explicit list — supplements FUNCTION_WORD_POS for
# edge cases that pymorphy3 mislabels or that have no clean POS category.
# ---------------------------------------------------------------------------
def load_function_words(path):
    """
    Returns a set of lowercase word strings from function_words_ru.txt.
    Lines starting with # are comments. Missing file returns empty set.
    """
    if not os.path.exists(path):
        return set()
    words = set()
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                words.add(line.lower())
    return words

# ---------------------------------------------------------------------------
# Letter utilities
# ---------------------------------------------------------------------------
def letter_counts(word):
    counts = {}
    for ch in word.lower():
        counts[ch] = counts.get(ch, 0) + 1
    return counts

def can_form(word, source_counts):
    wc = letter_counts(word)
    for ch, n in wc.items():
        if source_counts.get(ch, 0) < n:
            return False
    return True

# ---------------------------------------------------------------------------
# Word quality gate — LibreOffice Russian hunspell dictionary
#
# The hunspell dictionary is the authoritative source of what constitutes a
# real Russian word. It rejects ~76% of the words pymorphy3 would otherwise
# accept via morphological prediction (fragments, loanword noise, letter
# sequences that match Russian suffix patterns but are not real vocabulary).
# The frequency list is used only to look up corpus counts for classification.
# See docs/DECISIONS.md D12.
#
# Dictionary source: LibreOffice/dictionaries ru_RU
# https://github.com/LibreOffice/dictionaries/tree/master/ru_RU
# Licence: LGPL v3 / MPL 1.1 / GPL v3
# ---------------------------------------------------------------------------
hunspell = enchant.Dict('ru_RU')

# ---------------------------------------------------------------------------
# Lemmatization
# ---------------------------------------------------------------------------
morph = pymorphy3.MorphAnalyzer()

# Proper noun grammeme tags — filtered out entirely because they are not general
# vocabulary. May be added back manually for themed levels (geography,
# literature, etc.) via the level JSON overrides.
PROPER_NOUN_TAGS = {'Name', 'Surn', 'Patr', 'Geox', 'Orgn', 'Trad'}

# Function word POS tags — words with these POS are routed to tooCommon
# (not silently dropped) so the player sees "too common" feedback when
# they try to enter one. Pronouns, conjunctions, particles, prepositions,
# interjections, and predicatives are grammatical glue words; they are
# valid Russian words but make poor game targets.
# PREP was previously dropped silently; now it surfaces as tooCommon.
# See docs/DECISIONS.md D15.
FUNCTION_WORD_POS = {'PREP', 'NPRO', 'CONJ', 'PRCL', 'INTJ', 'PRED'}

# Module-level load of the explicit function words list. Most function words
# are caught by FUNCTION_WORD_POS; this file covers edge cases where
# pymorphy3 assigns an unexpected POS.
FUNCTION_WORDS = load_function_words(FUNCTION_WORDS_FILE)

def get_lemma(word):
    """
    Returns the canonical lemma for a word:
      - Nouns            → nominative singular
      - Verbs/infinitive → infinitive
      - Adjectives (full or short) → short form masculine singular
                          (краткая форма) where it exists, else masculine
                          nominative singular. Short form is preferred: it is
                          shorter, more literary, and fits the Soviet Notebook
                          aesthetic better than the clunky -ый/-ий ending.
      - Other POS        → pymorphy3 normal form

    Both ADJF (full) and ADJS (short) map to the same short-form lemma so
    that e.g. "красивый" and "красив" both resolve to "красив" and are
    treated as the same word.
    """
    parsed = morph.parse(word)
    if not parsed:
        return word

    # If the top parse is an abbreviation but a real-word parse also exists,
    # prefer the first non-abbreviation parse. This handles words like "род"
    # where pymorphy3 ranks an Abbr/verb parse above the common noun parse.
    p = parsed[0]
    if 'Abbr' in p.tag.grammemes:
        real = [x for x in parsed if 'Abbr' not in x.tag.grammemes and 'UNKN' not in x.tag.grammemes]
        if real:
            p = real[0]

    pos = p.tag.POS

    if pos == 'NOUN':
        inflected = p.inflect({'nomn', 'sing'})
        return inflected.word if inflected else p.normal_form

    if pos in ('VERB', 'INFN'):
        inflected = p.inflect({'INFN'})
        return inflected.word if inflected else p.normal_form

    if pos in ('ADJF', 'ADJS'):
        short = p.inflect({'ADJS', 'masc', 'sing'})
        if short:
            return short.word
        masc = p.inflect({'nomn', 'masc', 'sing'})
        return masc.word if masc else p.normal_form

    return p.normal_form

# ---------------------------------------------------------------------------
# Core generator — shared by all per-level functions
# ---------------------------------------------------------------------------
def generate_level(source_word, freq, overrides_excluded, blocklists,
                   min_length=3, max_length=5, freq_threshold=1000):
    """
    Generates word lists for a level. Always call with a difficulty profile:
        generate_level(..., **PROFILES['P2_EASY'])
    The default parameter values match P3_MEDIUM and exist only as a safety
    net — in practice every level function passes an explicit profile.

    Classification order (after quality gate):
      POS in FUNCTION_WORD_POS, or word in function_words_ru.txt → too_common
      min_length <= len <= max_length AND count >= freq_threshold → required
      otherwise (too short, too long, or too rare)               → bonus

    Only words that pass the hunspell quality gate are considered. The
    frequency list is used solely for corpus count lookup.

    blocked — words removed by the noise blocklist (not profanity). Included
    in the JSON output so curators can recover any real words mistakenly blocked.
    """
    src = source_word.lower()
    src_counts = letter_counts(src)
    excluded = {w.lower() for w in overrides_excluded}
    required = []
    bonus = []
    too_common = []
    blocked = []

    for word, count in freq.items():
        if len(word) < MIN_WORD_LENGTH or len(word) >= len(src):
            continue

        # Check formability first — cheap letter-count comparison.
        # Most words in the frequency list can't be formed from any given
        # source word, so this eliminates the vast majority before the
        # more expensive calls below.
        if not can_form(word, src_counts):
            continue

        # Hunspell quality gate — only admit words the Russian spell-checker
        # recognises. Rejects ~76% of pymorphy3's morphological predictions
        # (fragments, loanword noise, letter sequences matching Russian suffix
        # patterns but not real vocabulary). See docs/DECISIONS.md D12.
        if not hunspell.check(word):
            continue

        # Skip non-lemma forms — their lemma will appear in the frequency
        # list on its own and be processed then. This avoids duplicate entries
        # without needing a seen-set. Done after the hunspell gate so pymorphy3
        # is only called on words that actually pass.
        if get_lemma(word) != word:
            continue

        if word in excluded:
            continue

        parsed = morph.parse(word)
        if not parsed:
            continue

        # Filter proper nouns — not general vocabulary; may be added back
        # manually for themed levels (geography, literature, etc.).
        if parsed[0].tag.grammemes & PROPER_NOUN_TAGS:
            continue

        # Route function words to tooCommon so the player sees "too common"
        # feedback when they enter one, rather than getting no response.
        # Covers prepositions, pronouns, conjunctions, particles,
        # interjections, and predicatives. See docs/DECISIONS.md D15.
        pos = parsed[0].tag.POS
        if pos in FUNCTION_WORD_POS or word in FUNCTION_WORDS:
            too_common.append(word)
            continue

        # Noise blocklist — track these separately so curators can review.
        if word in blocklists.noise:
            blocked.append(word)
            continue

        # Profanity blocklist — silently dropped, not included in review output.
        if word in blocklists.profanity:
            continue

        if min_length <= len(word) <= max_length and count >= freq_threshold:
            required.append(word)
        else:
            bonus.append(word)

    required.sort(key=lambda w: (len(w), w))
    bonus.sort(key=lambda w: (len(w), w))
    too_common.sort(key=lambda w: (len(w), w))
    blocked.sort(key=lambda w: (len(w), w))
    return required, bonus, too_common, blocked

# ---------------------------------------------------------------------------
# Helper to reduce per-level boilerplate — mirrors generate_en.py's make_level().
# ---------------------------------------------------------------------------
def make_level(source_word, profile_name, freq, blocklists,
               overrides_excluded=None, overrides_included=None):
    overrides_excluded = overrides_excluded or []
    overrides_included = overrides_included or {}
    required, bonus, too_common, blocked = generate_level(
        source_word, freq, overrides_excluded, blocklists,
        **PROFILES[profile_name])

    for word in overrides_included.get('required', []):
        if word not in required:
            required.append(word)
    for word in overrides_included.get('bonus', []):
        if word not in bonus:
            bonus.append(word)
    required.sort(key=lambda w: (len(w), w))
    bonus.sort(key=lambda w: (len(w), w))

    entry = {
        "sourceWord": source_word,
        "profile": profile_name,
        "required": required,
        "bonus": bonus,
        "tooCommon": too_common,
        "blocked": blocked,
    }
    overrides = {}
    if overrides_excluded:
        overrides["excluded"] = overrides_excluded
    if overrides_included:
        overrides["included"] = overrides_included
    if overrides:
        entry["overrides"] = overrides
    return entry

# ---------------------------------------------------------------------------
# Per-level functions — named level_{tier}_{index} where tier is the
# difficulty number (1=beginner … 5=expert) and index restarts at 1 per tier.
# main() stamps "difficulty" and "levelNumber" onto each entry automatically.
# To add a level: add a function here, list it in LEVELS, and run the generator.
# Profile assignments verified by calibrate_ru.py against global vocabulary.
# ---------------------------------------------------------------------------

# --- Tier 1: P1_BEGINNER ---

def level_1_1(freq, blocklists):
    # строитель — P1_BEGINNER (~6 required)
    return make_level("строитель", 'P1_BEGINNER', freq, blocklists)

def level_1_2(freq, blocklists):
    # государство — P1_BEGINNER (~5 required)
    return make_level("государство", 'P1_BEGINNER', freq, blocklists)

def level_1_3(freq, blocklists):
    # сотрудник — P1_BEGINNER (~12 required)
    return make_level("сотрудник", 'P1_BEGINNER', freq, blocklists)

def level_1_4(freq, blocklists):
    # правительство — TODO: needs a replacement source word.
    # No profile gives fewer than 13 required words; letters form too many common words.
    # Temporary: P1_BEGINNER to minimise the excess.
    return make_level("правительство", 'P1_BEGINNER', freq, blocklists)

# --- Tier 2: P2_EASY ---

def level_2_1(freq, blocklists):
    # достижение — P2_EASY (~7 required)
    return make_level("достижение", 'P2_EASY', freq, blocklists)

def level_2_2(freq, blocklists):
    # холодильник — P2_EASY (~8 required)
    return make_level("холодильник", 'P2_EASY', freq, blocklists)

def level_2_3(freq, blocklists):
    # университет — P2_EASY (~8 required)
    return make_level("университет", 'P2_EASY', freq, blocklists)

def level_2_4(freq, blocklists):
    # воспитание — P2_EASY (~10 required)
    return make_level("воспитание", 'P2_EASY', freq, blocklists)

def level_2_5(freq, blocklists):
    # расстояние — P2_EASY (~10 required)
    return make_level("расстояние", 'P2_EASY', freq, blocklists)

def level_2_6(freq, blocklists):
    # переводчик — P2_EASY (~11 required)
    return make_level("переводчик", 'P2_EASY', freq, blocklists)

def level_2_7(freq, blocklists):
    # образование — P2_EASY (~11 required)
    return make_level("образование", 'P2_EASY', freq, blocklists)

def level_2_8(freq, blocklists):
    # произведение — P2_EASY (~12 required)
    return make_level("произведение", 'P2_EASY', freq, blocklists)

def level_2_9(freq, blocklists):
    # воображение — P2_EASY (~13 required)
    return make_level("воображение", 'P2_EASY', freq, blocklists)

# --- Tier 3: P3_MEDIUM ---

def level_3_1(freq, blocklists):
    # телевизор — P3_MEDIUM (~8 required)
    return make_level("телевизор", 'P3_MEDIUM', freq, blocklists)

def level_3_2(freq, blocklists):
    # приключение — P3_MEDIUM (~9 required)
    return make_level("приключение", 'P3_MEDIUM', freq, blocklists)

def level_3_3(freq, blocklists):
    # направление — P3_MEDIUM (~10 required)
    return make_level("направление", 'P3_MEDIUM', freq, blocklists)

def level_3_4(freq, blocklists):
    # картошка — P3_MEDIUM (~11 required)
    return make_level("картошка", 'P3_MEDIUM', freq, blocklists)

def level_3_5(freq, blocklists):
    # библиотека — P3_MEDIUM (~11 required)
    return make_level("библиотека", 'P3_MEDIUM', freq, blocklists)

def level_3_6(freq, blocklists):
    # архитектура — P3_MEDIUM (~13 required)
    return make_level("архитектура", 'P3_MEDIUM', freq, blocklists)

# --- Tier 4: P4_HARD ---

def level_4_1(freq, blocklists):
    # комсомолец — P4_HARD (~9 required)
    return make_level("комсомолец", 'P4_HARD', freq, blocklists)

# --- Tier 5: P5_EXPERT ---

def level_5_1(freq, blocklists):
    # математика — P5_EXPERT (~10 required)
    return make_level("математика", 'P5_EXPERT', freq, blocklists)

def level_5_2(freq, blocklists):
    # литература — P5_EXPERT (~12 required)
    return make_level("литература", 'P5_EXPERT', freq, blocklists)

def level_5_3(freq, blocklists):
    # территория — TODO: needs a replacement source word.
    # Max 5 required at any profile due to limited formable vocabulary.
    # Temporary: P5_EXPERT to surface as many words as possible.
    return make_level("территория", 'P5_EXPERT', freq, blocklists)

# ---------------------------------------------------------------------------
# Level registry — add new functions above and list them here in play order.
# main() assigns "difficulty" and "levelNumber" automatically from "profile".
# ---------------------------------------------------------------------------
LEVELS = [
    level_1_1, level_1_2, level_1_3, level_1_4,
    level_2_1, level_2_2, level_2_3, level_2_4, level_2_5,
    level_2_6, level_2_7, level_2_8, level_2_9,
    level_3_1, level_3_2, level_3_3, level_3_4, level_3_5, level_3_6,
    level_4_1,
    level_5_1, level_5_2, level_5_3,
]

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    # Ensure UTF-8 output on Windows.
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    freq = load_freq(FREQ_FILE)
    blocklists = load_blocklist(BLOCKLIST_FILE)
    if blocklists.noise or blocklists.profanity:
        print(f"Loaded {len(blocklists.noise)} noise + {len(blocklists.profanity)} profanity entries.")
    levels = []

    difficulty_counters: dict[str, int] = {}
    for level_fn in LEVELS:
        entry = level_fn(freq, blocklists)
        profile_name = entry.pop("profile")
        difficulty = PROFILE_DIFFICULTY[profile_name]
        difficulty_counters[difficulty] = difficulty_counters.get(difficulty, 0) + 1
        entry["difficulty"] = difficulty
        entry["levelNumber"] = difficulty_counters[difficulty]

        source_word = entry["sourceWord"]
        required_count = len(entry["required"])
        bonus_count = len(entry["bonus"])
        too_common_count = len(entry["tooCommon"])
        blocked_count = len(entry["blocked"])
        print(f"Generating: {source_word} ({len(source_word)} letters)  [{difficulty} #{difficulty_counters[difficulty]}]...")
        print(f"  required: {required_count}, bonus: {bonus_count}, too_common: {too_common_count}, blocked: {blocked_count}")
        levels.append(entry)

    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(levels, f, ensure_ascii=False, indent=2)

    print(f"\nWrote {len(levels)} levels to {OUTPUT_FILE}")

if __name__ == '__main__':
    main()

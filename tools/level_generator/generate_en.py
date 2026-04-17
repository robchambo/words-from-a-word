"""
English level generator for Слова из Слова.

Mirrors generate.py (Russian) with English-specific morphology and quality gate.
For each source word, produces required, bonus, too_common, and blocked word
lists, writing the result to assets/data/english_levels.json.

Usage:
    python generate_en.py

Word quality gate:
    The LibreOffice en_US hunspell dictionary is the primary source of truth
    for what counts as a real English word. Only words that pass the hunspell
    spell-checker are admitted. Mirrors the Russian generator's D12 approach.

    The frequency list (en_freq.txt, hermitdave English full list) serves as
    the iteration source AND the frequency lookup. Iterating over the hunspell
    .dic directly would miss inflected base forms the lemmatizer cares about,
    so hunspell is applied as a quality gate on top of the frequency list.

Word classification (applied after the quality gate):
    required   — base form, formable from source letters,
                 length <= max_length, freq_threshold <= count < max_freq
    bonus      — base form, formable from source letters,
                 length > max_length OR count < freq_threshold
    too_common — base form, formable from source letters, count >= max_freq
    blocked    — admitted by hunspell but on the noise blocklist (tracked for review)

Only base/lemma forms are kept; non-base inflections are skipped because their
lemma will appear in the frequency list separately.

ALL filtering happens here, not in the dictionary or the Flutter runtime.
See docs/DECISIONS.md D11 for rationale (Russian) — same principle for English.
"""

import io
import json
import os
import re
import sys
from collections import namedtuple
import enchant
import spacy

# UTF-8 stdout wrap is applied inside main() so importing this module
# (e.g. from tests or calibration) does not clobber sys.stdout.

# ---------------------------------------------------------------------------
# Hard floor — minimum word length, applied to every level regardless of profile.
# ---------------------------------------------------------------------------
MIN_WORD_LENGTH = 3

# ---------------------------------------------------------------------------
# Difficulty profiles — mirror the Russian generator's five-profile scheme.
# Values below are CALIBRATED for English (OpenSubtitles 2018 frequency).
# English vocabulary density is significantly higher than Russian, so the
# frequency thresholds are an order of magnitude stricter than Russian's.
#
#   Profile        ft       mf       ml    Notes
#   P1_BEGINNER  80000   500000     4     Most common short words only
#   P2_EASY      30000   200000     4     Common 4-letter vocabulary
#   P3_MEDIUM    10000    80000     5     Broader vocabulary, up to 5 letters
#   P4_HARD       3000    30000     5     Less common words, up to 5 letters
#   P5_EXPERT      800    15000     6     Rare/literary vocabulary, up to 6 letters
#
# ft = freq_threshold: words below this go to bonus
# mf = max_freq:       words at or above this go to too_common
# ml = max_length:     words longer than this go to bonus
#
# Calibrated against the 20 source words; 15/20 land in 7-13 required words
# at their best-fit profile. The 5 outliers (strawberry, newspaper,
# thunderstorm, pineapple, playground) are flagged with TODO comments below
# and use their best-fit profile pending source-word replacement.
# P5_EXPERT is unused at present — no source word is sparse enough to need
# its loose thresholds. Retained for future hard source words.
# ---------------------------------------------------------------------------
PROFILES = {
    'P1_BEGINNER': {'freq_threshold': 80000, 'max_freq': 500000, 'max_length': 4},
    'P2_EASY':     {'freq_threshold': 30000, 'max_freq': 200000, 'max_length': 4},
    'P3_MEDIUM':   {'freq_threshold': 10000, 'max_freq':  80000, 'max_length': 5},
    'P4_HARD':     {'freq_threshold':  3000, 'max_freq':  30000, 'max_length': 5},
    'P5_EXPERT':   {'freq_threshold':   800, 'max_freq':  15000, 'max_length': 6},
}

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
FREQ_FILE = os.path.join(SCRIPT_DIR, 'en_freq.txt')
BLOCKLIST_FILE = os.path.join(SCRIPT_DIR, 'blocklist_en.txt')
FUNCTION_WORDS_FILE = os.path.join(SCRIPT_DIR, 'function_words_en.txt')
OUTPUT_FILE = os.path.join(REPO_ROOT, 'assets', 'data', 'english_levels.json')

# ---------------------------------------------------------------------------
# Load frequency list
# ---------------------------------------------------------------------------
LATIN = re.compile(r"^[a-z]+$")

def load_freq(path):
    freq = {}
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split(' ')
            if len(parts) == 2 and LATIN.match(parts[0].lower()):
                word = parts[0].lower()
                count = int(parts[1]) if parts[1].isdigit() else 0
                # Keep the highest-count entry if a word appears twice
                if word not in freq or count > freq[word]:
                    freq[word] = count
    print(f"Loaded {len(freq):,} words from frequency list.")
    return freq

# ---------------------------------------------------------------------------
# Load blocklist — section-aware (mirrors Russian generator)
# ---------------------------------------------------------------------------
Blocklists = namedtuple('Blocklists', ['noise', 'profanity'])

def load_function_words(path):
    """
    Returns a set of lowercase word strings from function_words_en.txt.
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

def load_blocklist(path):
    """
    Parses blocklist_en.txt by section header.
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
# Word quality gate — LibreOffice en_US hunspell dictionary
# ---------------------------------------------------------------------------
hunspell = enchant.Dict('en_US')

# ---------------------------------------------------------------------------
# spaCy English model — lemmatization and POS tagging.
#
# Replaces NLTK for both tasks. spaCy tags isolated words reliably using
# Universal Dependencies (UD) tags, unlike NLTK's perceptron tagger which
# defaults to NN on isolated words (no sentence context).
#
# parser and ner are disabled — we only need tagger + lemmatizer.
# ---------------------------------------------------------------------------
nlp = spacy.load("en_core_web_sm", disable=["parser", "ner"])

def get_lemma_en(word):
    """
    Returns the canonical base form (lemma) for an English word using spaCy.

    Mirrors get_lemma() in the Russian generator: only words where
    get_lemma_en(word) == word are kept by generate_level() — all others
    are inflected forms whose lemma appears separately in the frequency list.
    """
    return nlp(word.lower())[0].lemma_

# ---------------------------------------------------------------------------
# POS-based filters — Universal Dependencies tags from spaCy.
# ---------------------------------------------------------------------------

# Proper nouns — filtered out entirely (not general vocabulary).
PROPER_NOUN_TAGS = {'PROPN'}

# Function word UD tags — routed to tooCommon. Mirrors FUNCTION_WORD_POS
# in generate_ru.py. See docs/DECISIONS.md D15.
#   ADP   — adpositions (prepositions: in, of, for)
#   PRON  — pronouns (he, she, it, they)
#   CCONJ — coordinating conjunctions (and, but, or)
#   SCONJ — subordinating conjunctions (if, because, although)
#   DET   — determiners (the, a, an, this)
#   INTJ  — interjections (oh, wow, hey)
#   PART  — particles (not, 's, to as infinitive marker)
FUNCTION_WORD_POS = {'ADP', 'PRON', 'CCONJ', 'SCONJ', 'DET', 'INTJ', 'PART'}

# Explicit function words list — supplements FUNCTION_WORD_POS for edge
# cases where spaCy assigns an unexpected tag on isolated words.
FUNCTION_WORDS = load_function_words(FUNCTION_WORDS_FILE)

def get_tag(word):
    """Returns the spaCy Universal Dependencies POS tag for a word."""
    return nlp(word.lower())[0].pos_

# ---------------------------------------------------------------------------
# Core generator
# ---------------------------------------------------------------------------
def generate_level(source_word, freq, overrides_excluded, blocklists,
                   min_length=MIN_WORD_LENGTH, max_length=5,
                   freq_threshold=1000, max_freq=20000):
    """
    Generates word lists for a level. Always call with a difficulty profile:
        generate_level(..., **PROFILES['P3_MEDIUM'])

    Classification order:
      count >= max_freq                                          → too_common
      len <= max_length AND freq_threshold <= count < max_freq    → required
      otherwise                                                  → bonus
    """
    src = source_word.lower()
    src_counts = letter_counts(src)
    excluded = {w.lower() for w in overrides_excluded}

    required = []
    bonus = []
    too_common = []
    blocked = []

    for word, count in freq.items():
        if len(word) < min_length or len(word) >= len(src):
            continue

        # Cheap formability check first — eliminates the vast majority of words.
        if not can_form(word, src_counts):
            continue

        # Hunspell quality gate.
        if not hunspell.check(word):
            continue

        # Skip non-base forms — their lemma will appear in the frequency list
        # separately.
        if get_lemma_en(word) != word:
            continue

        if word in excluded:
            continue

        # Drop proper nouns entirely — not general vocabulary.
        tag = get_tag(word)
        if tag in PROPER_NOUN_TAGS:
            continue

        # Route function words to tooCommon so the player sees "too common"
        # feedback when they enter one. See docs/DECISIONS.md D15.
        if tag in FUNCTION_WORD_POS or word in FUNCTION_WORDS:
            too_common.append(word)
            continue

        if word in blocklists.noise:
            blocked.append(word)
            continue
        if word in blocklists.profanity:
            continue

        if count >= max_freq:
            too_common.append(word)
        elif len(word) <= max_length and count >= freq_threshold:
            required.append(word)
        else:
            bonus.append(word)

    required.sort(key=lambda w: (len(w), w))
    bonus.sort(key=lambda w: (len(w), w))
    too_common.sort(key=lambda w: (len(w), w))
    blocked.sort(key=lambda w: (len(w), w))
    return required, bonus, too_common, blocked

# ---------------------------------------------------------------------------
# Helper to reduce per-level boilerplate. (Russian's per-level functions
# repeat the same 7-line template; here we collapse that into one call so the
# level functions are one-liners.)
# ---------------------------------------------------------------------------
def make_level(source_word, profile_name, freq, blocklists, overrides_excluded=None):
    overrides_excluded = overrides_excluded or []
    required, bonus, too_common, blocked = generate_level(
        source_word, freq, overrides_excluded, blocklists,
        **PROFILES[profile_name])
    entry = {
        "sourceWord": source_word,
        "profile": profile_name,
        "required": required,
        "bonus": bonus,
        "tooCommon": too_common,
        "blocked": blocked,
    }
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

# ---------------------------------------------------------------------------
# Per-level functions — named level_{tier}_{index} where tier is the
# difficulty number (1=beginner … 5=expert) and index restarts at 1 per tier.
# Profile assignments verified by calibrate_en.py against global vocabulary.
# ---------------------------------------------------------------------------

# --- Tier 1: P1_BEGINNER ---

def level_1_1(freq, blocklists):
    # breakfast — P1_BEGINNER (~8 required)
    return make_level("breakfast", 'P1_BEGINNER', freq, blocklists)

def level_1_2(freq, blocklists):
    # waterfall — P1_BEGINNER (~7 required)
    return make_level("waterfall", 'P1_BEGINNER', freq, blocklists)

def level_1_3(freq, blocklists):
    # chemistry — P1_BEGINNER (~8 required)
    return make_level("chemistry", 'P1_BEGINNER', freq, blocklists)

def level_1_4(freq, blocklists):
    # adventure — P1_BEGINNER (~11 required)
    return make_level("adventure", 'P1_BEGINNER', freq, blocklists)

def level_1_5(freq, blocklists):
    # strawberry — P1_BEGINNER (~10 required)
    return make_level("strawberry", 'P1_BEGINNER', freq, blocklists)

# --- Tier 2: P2_EASY ---

def level_2_1(freq, blocklists):
    # landscape — P2_EASY (~7 required)
    return make_level("landscape", 'P2_EASY', freq, blocklists)

def level_2_2(freq, blocklists):
    # springtime — P2_EASY (~10 required)
    return make_level("springtime", 'P2_EASY', freq, blocklists)

def level_2_3(freq, blocklists):
    # chocolate — P2_EASY (~10 required)
    return make_level("chocolate", 'P2_EASY', freq, blocklists)

def level_2_4(freq, blocklists):
    # carpenter — P2_EASY (~11 required)
    return make_level("carpenter", 'P2_EASY', freq, blocklists)

def level_2_5(freq, blocklists):
    # basketball — P2_EASY (~12 required)
    return make_level("basketball", 'P2_EASY', freq, blocklists)

def level_2_6(freq, blocklists):
    # playground — P2_EASY (~12 required)
    return make_level("playground", 'P2_EASY', freq, blocklists)

def level_2_7(freq, blocklists):
    # thunderstorm — TODO: source word too rich; ~16 required at best-fit profile (target 7-13).
    # Consider replacing with a sparser source word.
    return make_level("thunderstorm", 'P2_EASY', freq, blocklists)

# --- Tier 3: P3_MEDIUM ---

def level_3_1(freq, blocklists):
    # telephone — P3_MEDIUM (~8 required)
    return make_level("telephone", 'P3_MEDIUM', freq, blocklists)

def level_3_2(freq, blocklists):
    # mountains — P3_MEDIUM (~8 required)
    return make_level("mountains", 'P3_MEDIUM', freq, blocklists)

def level_3_3(freq, blocklists):
    # pineapple — P3_MEDIUM (~10 required)
    return make_level("pineapple", 'P3_MEDIUM', freq, blocklists)

def level_3_4(freq, blocklists):
    # blackboard — P3_MEDIUM (~12 required)
    return make_level("blackboard", 'P3_MEDIUM', freq, blocklists)

def level_3_5(freq, blocklists):
    # newspaper — P3_MEDIUM (~13 required)
    return make_level("newspaper", 'P3_MEDIUM', freq, blocklists)

# --- Tier 4: P4_HARD ---

def level_4_1(freq, blocklists):
    # fireworks — P4_HARD (~9 required)
    return make_level("fireworks", 'P4_HARD', freq, blocklists)

def level_4_2(freq, blocklists):
    # classroom — P4_HARD (~11 required)
    return make_level("classroom", 'P4_HARD', freq, blocklists)

def level_4_3(freq, blocklists):
    # butterfly — P4_HARD (~12 required)
    return make_level("butterfly", 'P4_HARD', freq, blocklists)

# --- Tier 5: P5_EXPERT ---
# (No source word currently calibrates to P5_EXPERT.)

# ---------------------------------------------------------------------------
# Level registry — ordered P1 → P5.
# main() stamps difficulty and levelNumber automatically from the profile.
# ---------------------------------------------------------------------------
LEVELS = [
    level_1_1, level_1_2, level_1_3, level_1_4, level_1_5,
    level_2_1, level_2_2, level_2_3, level_2_4, level_2_5, level_2_6, level_2_7,
    level_3_1, level_3_2, level_3_3, level_3_4, level_3_5,
    level_4_1, level_4_2, level_4_3,
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

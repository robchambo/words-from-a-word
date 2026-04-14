"""
Level generator for Слова из Слова.

For each source word, produces required, bonus, too_common, and blocked word
lists, writing the result to assets/data/russian_levels.json.

Usage:
    py generate.py

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
               length <= MAX_REQUIRED_LENGTH, frequency >= FREQ_THRESHOLD
    bonus    — in lemma form, formable from source letters,
               length > MAX_REQUIRED_LENGTH OR frequency < FREQ_THRESHOLD

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

# Ensure UTF-8 output on Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# ---------------------------------------------------------------------------
# Default thresholds — global fallbacks used when a level does not override.
# All four can be set per level via generate_level()'s keyword arguments:
#   min_length, max_length, freq_threshold, max_freq
#
# Classification (in order of precedence):
#   count >= MAX_FREQ                               → too_common
#   len <= MAX_REQUIRED_LENGTH AND count >= FREQ_THRESHOLD → required
#   otherwise                                       → bonus
# ---------------------------------------------------------------------------
MIN_WORD_LENGTH = 3          # shortest word to include
MAX_REQUIRED_LENGTH = 5      # words longer than this go to bonus
FREQ_THRESHOLD = 1000        # words below this frequency go to bonus
MAX_FREQ = 50000             # words at or above this frequency go to too_common

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.join(SCRIPT_DIR, '..', '..')
FREQ_FILE = os.path.join(REPO_ROOT, 'assets', 'data', 'ru_freq.txt')
BLOCKLIST_FILE = os.path.join(SCRIPT_DIR, 'blocklist.txt')
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
    Parses blocklist.txt by section header.
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

# Proper noun grammeme tags — filtered out because they are not general
# vocabulary. May be added back manually for themed levels (geography,
# literature, etc.) via the level JSON overrides.
PROPER_NOUN_TAGS = {'Name', 'Surn', 'Patr', 'Geox', 'Orgn', 'Trad'}

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
                   min_length=None, max_length=None, freq_threshold=None, max_freq=None):
    """
    Per-level overrides for classification thresholds.
    All default to the global constants when not specified.

    Classification order:
      count >= max_freq                                     → too_common
      len <= max_length AND freq_threshold <= count < max_freq → required
      otherwise                                             → bonus

    Only words that pass the hunspell quality gate are considered. The
    frequency list is used solely for corpus count lookup.

    blocked — words removed by the noise blocklist (not profanity). Included
    in the JSON output so curators can recover any real words mistakenly blocked.
    """
    src = source_word.lower()
    src_counts = letter_counts(src)
    excluded = {w.lower() for w in overrides_excluded}
    min_len   = min_length     if min_length     is not None else MIN_WORD_LENGTH
    max_len   = max_length     if max_length     is not None else MAX_REQUIRED_LENGTH
    threshold = freq_threshold if freq_threshold is not None else FREQ_THRESHOLD
    max_f     = max_freq       if max_freq       is not None else MAX_FREQ

    required = []
    bonus = []
    too_common = []
    blocked = []

    for word, count in freq.items():
        if len(word) < min_len or len(word) >= len(src):
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

        # Filter prepositions — short ones (в, на, по) feel like unearned
        # answers and clutter the required list. Longer ones (перед, вокруг)
        # may be added manually as bonus words for specific levels.
        if parsed[0].tag.POS == 'PREP':
            continue

        # Noise blocklist — track these separately so curators can review.
        if word in blocklists.noise:
            blocked.append(word)
            continue

        # Profanity blocklist — silently dropped, not included in review output.
        if word in blocklists.profanity:
            continue

        if count >= max_f:
            too_common.append(word)
        elif len(word) <= max_len and count >= threshold:
            required.append(word)
        else:
            bonus.append(word)

    required.sort(key=lambda w: (len(w), w))
    bonus.sort(key=lambda w: (len(w), w))
    too_common.sort(key=lambda w: (len(w), w))
    blocked.sort(key=lambda w: (len(w), w))
    return required, bonus, too_common, blocked

# ---------------------------------------------------------------------------
# Per-level functions
# Each function returns a dict ready to be appended to the levels list.
# To add a level: copy the template, increment the index, set source_word,
# and optionally populate overrides_excluded.
# ---------------------------------------------------------------------------

def level_01(freq, blocklists):
    # переводчик
    source_word = "переводчик"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_02(freq, blocklists):
    # строитель
    source_word = "строитель"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_03(freq, blocklists):
    # государство
    source_word = "государство"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_04(freq, blocklists):
    # воспитание
    source_word = "воспитание"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_05(freq, blocklists):
    # достижение
    source_word = "достижение"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_06(freq, blocklists):
    # образование
    source_word = "образование"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_07(freq, blocklists):
    # расстояние
    source_word = "расстояние"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_08(freq, blocklists):
    # направление
    source_word = "направление"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_09(freq, blocklists):
    # библиотека
    source_word = "библиотека"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_10(freq, blocklists):
    # правительство
    source_word = "правительство"
    overrides_excluded = []
    # Lower max_freq: this source word yields far too many required words at the
    # global threshold. Lowering max_freq moves more medium-high words to too_common.
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists,
                                                          max_freq=5000)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_11(freq, blocklists):
    # картошка
    source_word = "картошка"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_12(freq, blocklists):
    # комсомолец
    source_word = "комсомолец"
    overrides_excluded = []
    # Lower freq_threshold: formable vocabulary skews less frequent than the global default.
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists,
                                                          freq_threshold=200)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_13(freq, blocklists):
    # телевизор
    source_word = "телевизор"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_14(freq, blocklists):
    # холодильник
    source_word = "холодильник"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_15(freq, blocklists):
    # университет
    source_word = "университет"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_16(freq, blocklists):
    # литература
    source_word = "литература"
    overrides_excluded = []
    # Lower freq_threshold: formable vocabulary skews less frequent than the global default.
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists,
                                                          freq_threshold=200)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_17(freq, blocklists):
    # архитектура
    source_word = "архитектура"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_18(freq, blocklists):
    # математика
    source_word = "математика"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_19(freq, blocklists):
    # территория
    source_word = "территория"
    overrides_excluded = []
    # Lower freq_threshold: formable vocabulary skews less frequent than the global default.
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists,
                                                          freq_threshold=200)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_20(freq, blocklists):
    # сотрудник
    source_word = "сотрудник"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_21(freq, blocklists):
    # воображение
    source_word = "воображение"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_22(freq, blocklists):
    # произведение
    source_word = "произведение"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

def level_23(freq, blocklists):
    # приключение
    source_word = "приключение"
    overrides_excluded = []
    required, bonus, too_common, blocked = generate_level(source_word, freq, overrides_excluded, blocklists)
    entry = {"sourceWord": source_word, "required": required, "bonus": bonus, "tooCommon": too_common, "blocked": blocked}
    if overrides_excluded:
        entry["overrides"] = {"excluded": overrides_excluded}
    return entry

# ---------------------------------------------------------------------------
# Level registry — add new level functions here in order
# ---------------------------------------------------------------------------
LEVELS = [
    level_01, level_02, level_03, level_04, level_05,
    level_06, level_07, level_08, level_09, level_10,
    level_11, level_12, level_13, level_14, level_15,
    level_16, level_17, level_18, level_19, level_20,
    level_21, level_22, level_23,
]

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    freq = load_freq(FREQ_FILE)
    blocklists = load_blocklist(BLOCKLIST_FILE)
    if blocklists.noise or blocklists.profanity:
        print(f"Loaded {len(blocklists.noise)} noise + {len(blocklists.profanity)} profanity entries.")
    levels = []

    for level_fn in LEVELS:
        entry = level_fn(freq, blocklists)
        source_word = entry["sourceWord"]
        required_count = len(entry["required"])
        bonus_count = len(entry["bonus"])
        too_common_count = len(entry["tooCommon"])
        print(f"Generating: {source_word} ({len(source_word)} letters)...")
        blocked_count = len(entry["blocked"])
        print(f"  required: {required_count}, bonus: {bonus_count}, too_common: {too_common_count}, blocked: {blocked_count}")
        levels.append(entry)

    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(levels, f, ensure_ascii=False, indent=2)

    print(f"\nWrote {len(levels)} levels to {OUTPUT_FILE}")

if __name__ == '__main__':
    main()

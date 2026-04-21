"""
Scan vocab to find unambiguous source word candidates per profile.
Unambiguous = eligible for exactly one profile.
Eligibility: COUNT_MIN <= len(required_words) <= COUNT_MAX
Source word constraints (D16): 5–15 letters, nouns only.
COUNT_MAX=20 to surface words that need minor bonus trimming.
"""
import sys
import json
import os
import time

PROFILE_ORDER = ['P1_BEGINNER', 'P2_EASY', 'P3_MEDIUM', 'P4_HARD', 'P5_EXPERT']
COUNT_MIN = 5
COUNT_MAX = 20
SRC_MIN_LEN = 5
SRC_MAX_LEN = 15
SHOW = 15  # candidates to print per profile


def build_candidates(src, vocab_dict):
    src_set = set(src)
    return [(w, c) for w, c in vocab_dict.items()
            if set(w).issubset(src_set) and w != src and len(w) >= 3]


def get_required(candidates, profile, g):
    pr = g.PROFILES[profile]
    return [w for w, c in candidates
            if pr['min_length'] <= len(w) <= pr['max_length'] and c >= pr['freq_threshold']]


def is_noun_ru(word):
    import generate_ru as g
    parsed = g.morph.parse(word)
    if not parsed:
        return False
    return parsed[0].tag.POS == 'NOUN'


def is_noun_en(word):
    import generate_en as g
    return g.get_tag(word) == 'NOUN'


def find_seeds(lang):
    t0 = time.time()
    if lang == 'en':
        import generate_en as g
        cache = os.path.join(g.SCRIPT_DIR, 'vocab_cache_en.json')
        is_noun = is_noun_en
    else:
        import generate_ru as g
        cache = os.path.join(g.SCRIPT_DIR, 'vocab_cache_ru.json')
        is_noun = is_noun_ru

    with open(cache, encoding='utf-8') as f:
        vocab = [tuple(e) for e in json.load(f)]

    vocab_dict = dict(vocab)

    print(f"\n{'='*64}")
    print(f"LANGUAGE: {lang.upper()}   vocab: {len(vocab):,} lemmas")
    print(f"Source constraints: {SRC_MIN_LEN}–{SRC_MAX_LEN} letters, nouns only, "
          f"required count [{COUNT_MIN}, {COUNT_MAX}]")
    print(f"{'='*64}")

    buckets = {p: [] for p in PROFILE_ORDER}
    noun_candidates = [(w, c) for w, c in vocab if SRC_MIN_LEN <= len(w) <= SRC_MAX_LEN]
    print(f"Length-filtered candidates: {len(noun_candidates):,}  (checking POS...)")

    checked = 0
    nouns_found = 0
    for src, src_freq in noun_candidates:
        if not is_noun(src):
            continue
        nouns_found += 1

        candidates = build_candidates(src, vocab_dict)
        eligible = []
        for p in PROFILE_ORDER:
            req = get_required(candidates, p, g)
            if COUNT_MIN <= len(req) <= COUNT_MAX:
                eligible.append((p, len(req)))

        if len(eligible) == 1:
            p, nreq = eligible[0]
            buckets[p].append((src, src_freq, nreq))

        checked += 1
        if checked % 500 == 0:
            print(f"  {checked:,}/{len(noun_candidates):,} nouns checked  "
                  f"({time.time()-t0:.0f}s)", end='\r')

    print(f"  {nouns_found:,} nouns in range, {checked:,} checked  ({time.time()-t0:.1f}s)     ")

    for p in PROFILE_ORDER:
        words = buckets[p]
        words.sort(key=lambda x: x[1], reverse=True)
        pr = g.PROFILES[p]
        flag = "  ← needs trimming" if any(nreq > 15 for _, _, nreq in words[:SHOW]) else ""
        print(f"\n{p}  (len {pr['min_length']}–{pr['max_length']}, top {pr['percentile']}%)  "
              f"— {len(words)} unambiguous nouns{flag}")
        for src, freq, nreq in words[:SHOW]:
            note = " *" if nreq > 15 else ""
            print(f"  {src:<22} freq={freq:>8,}  required={nreq}{note}")

    print(f"\n(* = 16–20 required words; move extras to bonus to use)")


if __name__ == '__main__':
    langs = sys.argv[1:] or ['ru', 'en']
    for lang in langs:
        find_seeds(lang)

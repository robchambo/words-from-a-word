"""
Scan vocab to find unambiguous source word candidates per profile.
Unambiguous = eligible for exactly one profile.
Source word constraints (D16): 5-15 letters, nouns only.
COUNT_MAX=20 to surface words that need minor bonus trimming.

Sorted by gap_ratio: freq(last required) / freq(first excluded).
High ratio = clean natural cutoff. Low ratio = arbitrary line.
The threshold can be nudged slightly to land inside a natural gap.
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
SHOW = 20


def build_candidates(src, vocab_dict):
    src_set = set(src)
    return [(w, c) for w, c in vocab_dict.items()
            if set(w).issubset(src_set) and w != src and len(w) >= 3]


def get_window(candidates, profile, g):
    """All formable words in the profile's length window, sorted freq desc."""
    pr = g.PROFILES[profile]
    return sorted(
        [(w, c) for w, c in candidates
         if pr['min_length'] <= len(w) <= pr['max_length']],
        key=lambda x: x[1], reverse=True
    )


def gap_ratio(window, ft):
    """
    Ratio of last-required-freq to first-excluded-freq.
    Higher = cleaner natural cutoff. Returns 1.0 if no gap info available.
    """
    req = [c for _, c in window if c >= ft]
    exc = [c for _, c in window if c < ft]
    if not req or not exc:
        return 1.0
    return req[-1] / exc[0]


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

    print()
    print('=' * 64)
    print(f'LANGUAGE: {lang.upper()}   vocab: {len(vocab):,} lemmas')
    print(f'Source: {SRC_MIN_LEN}-{SRC_MAX_LEN} letters, nouns, required [{COUNT_MIN},{COUNT_MAX}]')
    print('Sorted by gap_ratio (last-required-freq / first-excluded-freq)')
    print('=' * 64)

    buckets = {p: [] for p in PROFILE_ORDER}
    noun_candidates = [(w, c) for w, c in vocab if SRC_MIN_LEN <= len(w) <= SRC_MAX_LEN]
    print(f'Length-filtered candidates: {len(noun_candidates):,}  (checking POS...)')
    # Note: diminutives are not automatically filtered (pymorphy3 has no Dimin tag).
    # Review output manually and exclude diminutives before adding to SOURCE_WORDS.

    checked = 0
    for src, src_freq in noun_candidates:
        if not is_noun(src):
            continue

        candidates = build_candidates(src, vocab_dict)
        eligible = []
        for p in PROFILE_ORDER:
            pr = g.PROFILES[p]
            window = get_window(candidates, p, g)
            req = [w for w, c in window if c >= pr['freq_threshold']]
            if COUNT_MIN <= len(req) <= COUNT_MAX:
                gr = gap_ratio(window, pr['freq_threshold'])
                eligible.append((p, len(req), gr))

        if len(eligible) == 1:
            p, nreq, gr = eligible[0]
            buckets[p].append((src, src_freq, nreq, gr))

        checked += 1
        if checked % 500 == 0:
            print(f'  {checked:,}/{len(noun_candidates):,} checked  '
                  f'({time.time()-t0:.0f}s)', end='\r')

    print(f'  {checked:,} nouns checked  ({time.time()-t0:.1f}s)     ')

    for p in PROFILE_ORDER:
        words = buckets[p]
        # Sort by gap_ratio descending (cleanest cutoffs first)
        words.sort(key=lambda x: x[3], reverse=True)
        pr = g.PROFILES[p]
        print()
        print(f'{p}  len {pr["min_length"]}-{pr["max_length"]}, '
              f'top {pr["percentile"]}%  --  {len(words)} unambiguous nouns')
        print(f'  {"word":<22} {"freq":>8}  {"req":>4}  {"gap":>6}  note')
        print(f'  {"-"*60}')
        for src, freq, nreq, gr in words[:SHOW]:
            trim = ' [trim]' if nreq > 15 else ''
            print(f'  {src:<22} {freq:>8,}  {nreq:>4}  {gr:>6.2f}{trim}')

    print()
    print('[trim] = 16-20 required; move extras to bonus')
    print('gap   = freq(last required) / freq(first excluded); >2.0 is clean')


if __name__ == '__main__':
    langs = sys.argv[1:] or ['ru', 'en']
    for lang in langs:
        find_seeds(lang)

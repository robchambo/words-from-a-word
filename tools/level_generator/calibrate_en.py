"""
Global vocabulary calibration for the English level generator.

Two-phase tool — mirrors calibrate_ru.py for English.

  Phase 1 — Global vocabulary build
    Runs the full en_freq.txt through the same quality gate as generate_en.py
    (hunspell + spaCy lemma + POS filters + blocklist), without any
    formability constraint. Caches the resulting set of (word, count) pairs
    to vocab_cache_en.json. Expensive on first run (~1–3 min); subsequent
    runs load from cache in seconds.

    After building the cache, prints vocabulary frequency distribution
    statistics and verifies freq_threshold percentile cutoffs for PROFILES
    in generate_en.py.

  Phase 2 — Source word evaluation
    For each source word, computes required words at every profile and finds
    the eligible profiles — those where required count falls in [COUNT_MIN,
    COUNT_MAX]. For each eligible profile the required word list and its
    median frequency are shown.

    Suggested assignment: for ambiguous words (eligible at multiple profiles),
    the suggestion uses log-scale median distance to targets derived from
    unambiguous and manually assigned words.

    Manual assignments are stored in manual_assignments_en.json and are never
    overwritten by the calibrator. Edit that file directly after reviewing the
    output. The calibrator flags words with no manual assignment yet and warns
    if a manual assignment has drifted out of the eligible range.

Usage:
    python calibrate_en.py              # load cache if present, else build it
    python calibrate_en.py --rebuild    # force rebuild the cache

Re-run whenever:
  - A new source word is being evaluated for a level
  - PROFILES values are being adjusted
  - A TODO source word is being replaced
  - The blocklist is significantly updated (run with --rebuild)

See calibrate_ru.py for the equivalent Russian tool.
"""

import argparse
import json
import math
import os
import sys
import time
import io
# Importing generate_en (rather than duplicating its logic) ensures the calibrator
# runs the identical quality gate — hunspell, lemma filter, POS filter, blocklist,
# can_form, letter_counts — so calibration results are guaranteed to match what
# the generator would produce for the same source word.
import generate_en as g

CACHE_FILE  = os.path.join(g.SCRIPT_DIR, 'vocab_cache_en.json')
MANUAL_FILE = os.path.join(g.SCRIPT_DIR, 'manual_assignments_en.json')

# Eligible profile band: required word count must fall in [COUNT_MIN, COUNT_MAX].
COUNT_MIN = 5
COUNT_MAX = 15

SOURCE_WORDS = [
    "strawberry", "carpenter", "chocolate", "mountains", "blackboard",
    "breakfast", "telephone", "adventure", "fireworks", "landscape",
    "waterfall", "butterfly", "classroom", "newspaper", "basketball",
    "thunderstorm", "springtime", "pineapple", "chemistry", "playground",
]

PROFILE_ORDER = ['P1_BEGINNER', 'P2_EASY', 'P3_MEDIUM', 'P4_HARD', 'P5_EXPERT']

# Percentile points to report in the distribution summary.
PERCENTILES = [50, 75, 90, 95, 99]


# ---------------------------------------------------------------------------
# Phase 1 — global vocabulary build and cache
# ---------------------------------------------------------------------------

def build_global_vocab(freq, blocklists):
    """
    Runs the full frequency list through the generate_en quality gate
    (hunspell + spaCy lemma + POS filters + blocklist) without any
    formability constraint. Returns a list of (word, count) pairs for all
    valid English lemmas, sorted by count descending.

    This is the expensive step; results are cached to vocab_cache_en.json.
    """
    print("Building global vocabulary (this may take 1-3 min)...")
    t0 = time.time()
    vocab = []
    checked = 0

    for word, count in freq.items():
        if len(word) < g.MIN_WORD_LENGTH:
            continue
        if not g.hunspell.check(word):
            continue
        if g.get_lemma_en(word) != word:
            continue

        tag = g.get_tag(word)
        if tag in g.PROPER_NOUN_TAGS:
            continue
        if tag in g.FUNCTION_WORD_POS or word in g.FUNCTION_WORDS:
            continue

        if word in blocklists.profanity or word in blocklists.noise:
            continue

        vocab.append((word, count))
        checked += 1
        if checked % 10000 == 0:
            print(f"  {checked:,} valid lemmas found  ({time.time()-t0:.0f}s)", end='\r')

    vocab.sort(key=lambda x: x[1], reverse=True)
    print(f"\nGlobal vocab: {len(vocab):,} valid lemmas  ({time.time()-t0:.1f}s)")
    return vocab


def load_or_build_vocab(freq, blocklists, force_rebuild=False):
    if not force_rebuild and os.path.exists(CACHE_FILE):
        print(f"Loading vocab cache from {os.path.basename(CACHE_FILE)}...")
        with open(CACHE_FILE, encoding='utf-8') as f:
            data = json.load(f)
        vocab = [tuple(entry) for entry in data]
        print(f"  {len(vocab):,} valid lemmas loaded.")
        return vocab

    vocab = build_global_vocab(freq, blocklists)
    with open(CACHE_FILE, 'w', encoding='utf-8') as f:
        json.dump(vocab, f, ensure_ascii=False)
    print(f"Vocab cache written to {os.path.basename(CACHE_FILE)}")
    return vocab


# ---------------------------------------------------------------------------
# Phase 1 output — frequency distribution stats
# ---------------------------------------------------------------------------

def compute_threshold_at_percentile(vocab, top_pct):
    """
    Returns the freq_threshold corresponding to the top N% of the global vocab.
    E.g. top_pct=5 → returns the count such that 5% of lemmas are above it.
    """
    counts = sorted((c for _, c in vocab), reverse=True)
    n = len(counts)
    idx = int((top_pct / 100) * n)
    idx = min(idx, n - 1)
    return counts[idx]


def print_distribution_stats(vocab):
    """
    Prints frequency distribution of the global vocab and the corpus-anchored
    freq_threshold values used in PROFILES (top 1/5/10/15/20% cutoffs).
    """
    if not vocab:
        return
    counts = [count for _, count in vocab]
    n = len(counts)

    print()
    print(f"Global vocabulary: {n:,} valid English lemmas")
    print(f"  Frequency range: {counts[-1]:,} – {counts[0]:,}")
    print()
    print("Frequency at percentile cutoffs:")
    print("  (words ABOVE this count are in the top X% of vocabulary)")
    print()
    for p in PERCENTILES:
        idx = int((1 - p / 100) * n)
        idx = max(0, min(idx, n - 1))
        cutoff = counts[idx]
        print(f"  top {100-p:2d}% (p{p:2d}): count >= {cutoff:>8,}  "
              f"({int(p/100 * n):,} words above)")
    print()
    print("Corpus-anchored freq_threshold values (used in PROFILES):")
    profile_pcts = [(p, g.PROFILES[p]['percentile']) for p in PROFILE_ORDER]
    for profile, pct in profile_pcts:
        threshold = compute_threshold_at_percentile(vocab, pct)
        current = g.PROFILES[profile]['freq_threshold']
        match = "✓" if abs(current - threshold) / max(threshold, 1) < 0.1 else f"(current: {current:,})"
        print(f"  {profile:<14} top {pct:2d}%  →  freq_threshold >= {threshold:>8,}  {match}")


# ---------------------------------------------------------------------------
# Phase 2 — source word evaluation
# ---------------------------------------------------------------------------

def build_candidates_from_vocab(source_word, vocab):
    """
    Filters the global vocab to words formable from source_word's letters
    and shorter than source_word. This full-vocab scan runs once per source
    word; get_required() then filters this smaller set per profile cheaply.
    """
    src_counts = g.letter_counts(source_word.lower())
    src_len = len(source_word)
    return [
        (word, count) for word, count in vocab
        if len(word) < src_len and g.can_form(word, src_counts)
    ]


def load_manual():
    """Loads manual profile assignments from MANUAL_FILE. Returns {} if absent."""
    if not os.path.exists(MANUAL_FILE):
        return {}
    with open(MANUAL_FILE, encoding='utf-8') as f:
        return json.load(f)


def get_required(candidates, profile):
    """
    Filters pre-computed formable candidates to those required under the given
    profile. Expects candidates from build_candidates_from_vocab — the full-vocab
    scan happens once per source word there, not once per profile here.
    """
    pr = g.PROFILES[profile]
    words = [(w, c) for w, c in candidates
             if pr['min_length'] <= len(w) <= pr['max_length']
             and c >= pr['freq_threshold']]
    words.sort(key=lambda x: x[1], reverse=True)
    return words


def get_gap_ratio(candidates, profile):
    """
    Ratio of the last required word's freq to the first excluded word's freq
    within the profile's length window. Higher = more natural cutoff.
    Prefer source words with gap >= 2.0 (decent) or >= 4.0 (clean).
    This is a soft preference for source word selection, not a hard filter —
    clean gaps are only ~4-13% of eligible words regardless of threshold.
    Returns None if one side of the gap is empty.
    """
    pr = g.PROFILES[profile]
    window = sorted(
        [(w, c) for w, c in candidates
         if pr['min_length'] <= len(w) <= pr['max_length']],
        key=lambda x: x[1], reverse=True
    )
    req = [c for _, c in window if c >= pr['freq_threshold']]
    exc = [c for _, c in window if c < pr['freq_threshold']]
    if not req or not exc:
        return None
    return req[-1] / exc[0]


def get_near_miss(candidates, profile, n=5):
    """
    Returns up to n formable words that just missed the required threshold for
    this profile — freq in [ft÷2, ft), within the profile's length window.

    The ft÷2 lower bound is one log-step below the threshold: on the Zipf
    frequency distribution, halving is as close as doubling, so ft÷2 captures
    the natural 'borderline' zone without expanding into genuinely rare words.
    These are candidates worth considering for manual promotion to required via
    level overrides.
    """
    pr = g.PROFILES[profile]
    ft = pr['freq_threshold']
    words = [(w, c) for w, c in candidates
             if pr['min_length'] <= len(w) <= pr['max_length']
             and ft // 2 <= c < ft]
    words.sort(key=lambda x: x[1], reverse=True)
    return words[:n]


def median_of(word_count_pairs):
    """Returns median corpus frequency of a list of (word, count) pairs."""
    if not word_count_pairs:
        return 0
    counts = sorted(c for _, c in word_count_pairs)
    n = len(counts)
    mid = n // 2
    return counts[mid] if n % 2 else (counts[mid - 1] + counts[mid]) // 2


def geo_mean(values):
    if not values:
        return None
    return math.exp(sum(math.log(max(v, 1)) for v in values) / len(values))


def compute_targets(all_required, all_eligible, manual):
    """
    Computes median-based suggestion targets per profile from unambiguous
    assignments (only one eligible profile) and confirmed manual assignments.
    Ambiguous words without a manual assignment do not contribute.
    """
    pools = {p: [] for p in PROFILE_ORDER}
    for src in SOURCE_WORDS:
        el = all_eligible[src]
        anchor = None
        if len(el) == 1:
            anchor = el[0]
        elif manual.get(src) in el:
            anchor = manual[src]
        if anchor:
            pools[anchor].append(median_of(all_required[src][anchor]))
    return {p: geo_mean(pools[p]) for p in PROFILE_ORDER}


def suggest_profile(eligible, all_required_for_src, candidates, targets):
    """
    Primary: median of required words, matched to per-profile targets derived
    from seeded anchor words (log-scale distance). This is the feel signal —
    it measures where the required words actually sit in frequency space.

    Secondary (tiebreaker): gap_ratio — prefer the profile where the frequency
    cutoff is cleanest. This breaks ties without overriding the feel signal.

    Falls back to the first eligible profile when no targets are seeded yet.
    The suggestion is unreliable until SOURCE_WORDS has enough anchor words to
    populate targets for each profile.
    """
    set_p = [p for p in eligible if targets.get(p) is not None]
    if not set_p:
        return eligible[0]

    def log_dist(p):
        med = median_of(all_required_for_src[p])
        return abs(math.log(max(med, 1)) - math.log(max(targets[p], 1)))

    def gap(p):
        gr = get_gap_ratio(candidates, p)
        return gr if gr is not None else 0.0

    return min(set_p, key=lambda p: (log_dist(p), -gap(p)))


def pshort(profile):
    return profile.split('_')[0]


def wrap_words(words, first_prefix, cont_prefix, line_width=72):
    """Wraps a word list across lines with consistent indentation."""
    if not words:
        return None
    lines = []
    current = first_prefix + words[0]
    for word in words[1:]:
        if len(current) + 2 + len(word) > line_width:
            lines.append(current)
            current = cont_prefix + word
        else:
            current += '  ' + word
    lines.append(current)
    return '\n'.join(lines)


def print_source_word_detail(vocab, manual):
    print("\nBuilding required word sets...")
    t0 = time.time()

    all_required = {}
    all_eligible = {}
    for src in SOURCE_WORDS:
        candidates = build_candidates_from_vocab(src, vocab)
        req = {p: get_required(candidates, p) for p in PROFILE_ORDER}
        all_required[src] = req
        all_eligible[src] = [p for p in PROFILE_ORDER
                              if COUNT_MIN <= len(req[p]) <= COUNT_MAX]
    print(f"  ({time.time()-t0:.1f}s)")

    targets = compute_targets(all_required, all_eligible, manual)

    print()
    print("Suggestion targets (from unambiguous + manual anchors):")
    for p in PROFILE_ORDER:
        t = targets[p]
        print(f"  {pshort(p)}  {f'{t:,.0f}' if t else 'none (no anchor words yet)'}")

    unclassified = [s for s in SOURCE_WORDS
                    if s not in manual and all_eligible.get(s)]
    classified   = [s for s in SOURCE_WORDS if s in manual]

    for section, section_words in [("UNCLASSIFIED", unclassified),
                                    ("CLASSIFIED",   classified)]:
        if not section_words:
            continue
        print(f"\n{'═' * 64}")
        print(f"{section} ({len(section_words)})")
        print(f"{'═' * 64}")

        for src in section_words:
            req      = all_required[src]
            eligible = all_eligible[src]
            man      = manual.get(src)
            sug      = suggest_profile(eligible, req, targets) if eligible else None

            el_str = ' '.join(pshort(p) for p in eligible) if eligible else 'none'
            if man:
                match = '✓' if man == sug else '✗'
                sug_str = pshort(sug) if sug else '—'
                print(f"\n{src:<16}  manual: {pshort(man)}   "
                      f"suggested: {sug_str}  {match}")
            else:
                print(f"\n{src:<16}  eligible: {el_str:<20}  "
                      f"suggested: {pshort(sug) if sug else '—'}")

            prev_set   = None
            prev_order = []
            candidates = build_candidates_from_vocab(src, vocab)
            for p in eligible:
                words    = req[p]
                curr_set = set(w for w, _ in words)
                med      = median_of(words)
                n        = len(words)
                man_tag  = '  [MANUAL]' if p == man else ''
                gr       = get_gap_ratio(candidates, p)
                gr_str   = f'  gap={gr:.1f}' if gr is not None else ''
                print(f"  {pshort(p)}  {n:2d}w  med {med:>8,}{man_tag}{gr_str}")

                if prev_set is None:
                    line = wrap_words([w for w, _ in words], '    ', '    ')
                else:
                    removed = [w for w in prev_order if w not in curr_set]
                    added   = [w for w, _ in words   if w not in prev_set]
                    if removed:
                        line = wrap_words(removed, '    − ', '      ')
                        if line: print(line)
                    line = wrap_words(added, '    + ', '      ') if added else None
                    if not removed and not added:
                        line = '    (no change)'

                if line: print(line)

                near = get_near_miss(candidates, p)
                if near:
                    nm_line = wrap_words([w for w, _ in near], '    ↓ ', '      ')
                    if nm_line: print(nm_line)

                prev_set   = curr_set
                prev_order = [w for w, _ in words]

    # Summary
    no_eligible  = [s for s in SOURCE_WORDS if not all_eligible[s]]
    out_of_range = [s for s in SOURCE_WORDS
                    if manual.get(s) and manual[s] not in all_eligible.get(s, [])]
    pending      = [s for s in SOURCE_WORDS
                    if s not in manual and all_eligible.get(s)]

    print(f"\n{'═' * 64}")
    print(f"Summary: {len(SOURCE_WORDS)} source words  |  "
          f"{len(manual)} manual  |  {len(pending)} pending")
    if no_eligible:
        print(f"\n  ✗ No eligible profile (replace these):")
        for s in no_eligible:
            counts_str = '  '.join(f"{pshort(p)}={len(all_required[s][p])}"
                                   for p in PROFILE_ORDER)
            print(f"    {s:<16}  {counts_str}")
    if out_of_range:
        print(f"\n  ⚠ Manual assignment out of range:")
        for s in out_of_range:
            man_p     = manual[s]
            man_count = len(all_required[s][man_p])
            el_str    = '  '.join(f"{pshort(p)}({len(all_required[s][p])})"
                                  for p in all_eligible[s]) or 'none'
            print(f"    {s:<16}  manual={pshort(man_p)}({man_count})   "
                  f"eligible=[{el_str}]")
    if pending:
        print(f"\n  Pending manual assignments:")
        for s in pending:
            sug = suggest_profile(all_eligible[s], all_required[s], targets)
            print(f"    {s:<16}  suggested: {pshort(sug)}")
    print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Calibrate English level generator profiles.")
    parser.add_argument('--rebuild', action='store_true',
                        help='Force rebuild the global vocab cache.')
    args = parser.parse_args()

    freq       = g.load_freq(g.FREQ_FILE)
    blocklists = g.load_blocklist(g.BLOCKLIST_FILE)
    manual     = load_manual()

    vocab = load_or_build_vocab(freq, blocklists, force_rebuild=args.rebuild)

    print_distribution_stats(vocab)
    print_source_word_detail(vocab, manual)


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    main()

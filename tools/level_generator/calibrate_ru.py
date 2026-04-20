"""
Global vocabulary calibration for the Russian level generator.

Two-phase tool:

  Phase 1 — Global vocabulary build
    Runs the full ru_freq.txt through the same quality gate as generate_ru.py
    (hunspell + pymorphy3 lemma + POS filters + blocklist), without any
    formability constraint. Caches the resulting set of (word, count) pairs
    to vocab_cache_ru.json. Expensive on first run (~1–2 min); subsequent
    runs load from cache in seconds.

    After building the cache, prints vocabulary frequency distribution
    statistics and verifies freq_threshold percentile cutoffs for PROFILES
    in generate_ru.py.

  Phase 2 — Source word evaluation
    For each source word, computes required words at every profile and finds
    the eligible profiles — those where required count falls in [COUNT_MIN,
    COUNT_MAX]. For each eligible profile the required word list and its
    median frequency are shown.

    Suggested assignment: for ambiguous words (eligible at multiple profiles),
    the suggestion uses log-scale median distance to targets derived from
    unambiguous and manually assigned words.

    Manual assignments are stored in manual_assignments_ru.json and are never
    overwritten by the calibrator. Edit that file directly after reviewing the
    output. The calibrator flags words with no manual assignment yet and warns
    if a manual assignment has drifted out of the eligible range.

Usage:
    py calibrate_ru.py              # load cache if present, else build it
    py calibrate_ru.py --rebuild    # force rebuild the cache

Re-run whenever:
  - A new source word is being evaluated for a level
  - PROFILES values are being adjusted
  - A TODO source word is being replaced
  - The blocklist is significantly updated (run with --rebuild)

See calibrate_en.py for the equivalent English tool.
"""

import argparse
import json
import math
import os
import sys
import time
import io
import generate_ru as g

CACHE_FILE  = os.path.join(g.SCRIPT_DIR, 'vocab_cache_ru.json')
MANUAL_FILE = os.path.join(g.SCRIPT_DIR, 'manual_assignments_ru.json')

# Eligible profile band: required word count must fall in [COUNT_MIN, COUNT_MAX].
COUNT_MIN = 5
COUNT_MAX = 15

SOURCE_WORDS = [
    "строитель", "государство", "воображение", "воспитание", "сотрудник",
    "правительство", "достижение", "архитектура", "библиотека", "холодильник",
    "университет", "расстояние", "переводчик", "образование", "произведение",
    "телевизор", "приключение", "картошка", "направление",
    "литература", "комсомолец",
    "математика", "территория",
]

PROFILE_ORDER = ['P1_BEGINNER', 'P2_EASY', 'P3_MEDIUM', 'P4_HARD', 'P5_EXPERT']

# Percentile points to report in the distribution summary.
PERCENTILES = [50, 75, 90, 95, 99]


# ---------------------------------------------------------------------------
# Phase 1 — global vocabulary build and cache
# ---------------------------------------------------------------------------

def build_global_vocab(freq, blocklists):
    """
    Runs the full frequency list through the generate_ru quality gate
    (hunspell + pymorphy3 lemma + POS filters + blocklist) without any
    formability constraint. Returns a list of (word, count) pairs for all
    valid Russian lemmas, sorted by count descending.

    This is the expensive step; results are cached to vocab_cache_ru.json.
    """
    print("Building global vocabulary (this takes ~1-2 min)...")
    t0 = time.time()
    vocab = []
    checked = 0

    for word, count in freq.items():
        if len(word) < g.MIN_WORD_LENGTH:
            continue
        if not g.hunspell.check(word):
            continue
        if g.get_lemma(word) != word:
            continue

        parsed = g.morph.parse(word)
        if not parsed:
            continue
        if parsed[0].tag.grammemes & g.PROPER_NOUN_TAGS:
            continue

        pos = parsed[0].tag.POS
        if pos in g.FUNCTION_WORD_POS or word in g.FUNCTION_WORDS:
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
    freq_threshold values used in PROFILES (top 2/5/10/15/20% cutoffs).
    """
    if not vocab:
        return
    counts = [count for _, count in vocab]
    n = len(counts)

    print()
    print(f"Global vocabulary: {n:,} valid Russian lemmas")
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
    profile_pcts = [('P1_BEGINNER', 2), ('P2_EASY', 5), ('P3_MEDIUM', 10),
                    ('P4_HARD', 15), ('P5_EXPERT', 20)]
    for profile, pct in profile_pcts:
        threshold = compute_threshold_at_percentile(vocab, pct)
        current = g.PROFILES[profile]['freq_threshold']
        match = "✓" if abs(current - threshold) / max(threshold, 1) < 0.1 else f"(current: {current:,})"
        print(f"  {profile:<14} top {pct:2d}%  →  freq_threshold >= {threshold:>8,}  {match}")


# ---------------------------------------------------------------------------
# Phase 2 — source word evaluation
# ---------------------------------------------------------------------------

def load_manual():
    """Loads manual profile assignments from MANUAL_FILE. Returns {} if absent."""
    if not os.path.exists(MANUAL_FILE):
        return {}
    with open(MANUAL_FILE, encoding='utf-8') as f:
        return json.load(f)


def get_required(source_word, vocab, profile):
    """
    Returns list of (word, count) required under the given profile for this
    source word, sorted by count descending.
    """
    pr = g.PROFILES[profile]
    sc = g.letter_counts(source_word.lower())
    words = [(w, c) for w, c in vocab
             if len(w) < len(source_word) and g.can_form(w, sc)
             and pr['min_length'] <= len(w) <= pr['max_length']
             and c >= pr['freq_threshold']]
    words.sort(key=lambda x: x[1], reverse=True)
    return words


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


def suggest_profile(eligible, all_required_for_src, targets):
    """
    Among eligible profiles, returns the one whose required-word median is
    closest (log-scale) to the computed target for that profile.
    Falls back to the first eligible profile if no targets are set.
    """
    set_p = [p for p in eligible if targets.get(p) is not None]
    if not set_p:
        return eligible[0]

    def log_dist(p):
        med = median_of(all_required_for_src[p])
        return abs(math.log(max(med, 1)) - math.log(max(targets[p], 1)))

    return min(set_p, key=lambda p: (log_dist(p), PROFILE_ORDER.index(p)))


def print_source_word_detail(vocab, manual):
    print("\nBuilding required word sets...")
    t0 = time.time()

    all_required = {}
    all_eligible = {}
    for src in SOURCE_WORDS:
        req = {p: get_required(src, vocab, p) for p in PROFILE_ORDER}
        all_required[src] = req
        all_eligible[src] = [p for p in PROFILE_ORDER
                              if COUNT_MIN <= len(req[p]) <= COUNT_MAX]
    print(f"  ({time.time()-t0:.1f}s)")

    targets = compute_targets(all_required, all_eligible, manual)

    print()
    print(f"Suggestion targets (from unambiguous + manual anchors):")
    for p in PROFILE_ORDER:
        t = targets[p]
        print(f"  {p:<14}  {f'{t:,.0f}' if t else 'none (no anchor words yet)'}")

    for src in SOURCE_WORDS:
        req      = all_required[src]
        eligible = all_eligible[src]
        man      = manual.get(src)
        sug      = suggest_profile(eligible, req, targets) if eligible else None

        print(f"\n{'─' * 64}")
        print(f"  {src}")
        print(f"{'─' * 64}")

        for p in PROFILE_ORDER:
            words = req[p]
            n     = len(words)
            in_el = p in eligible

            tags = []
            if p == sug:
                tags.append("SUGGESTED")
            if p == man:
                tags.append("MANUAL ✓" if in_el else "MANUAL ⚠ out of range")
            tag_str = f"  [{' | '.join(tags)}]" if tags else ""

            if in_el or p == man:
                med = median_of(words)
                pr  = g.PROFILES[p]
                print(f"\n  {p}  ({n} words, ft={pr['freq_threshold']:,}, "
                      f"len {pr['min_length']}–{pr['max_length']}, median {med:,}){tag_str}")
                print("    " + "  ".join(f"{w}({c:,})" for w, c in words))
            else:
                reason = "too few" if n < COUNT_MIN else "too many"
                print(f"  {p:<14}  {n} words — {reason}")

        if not eligible:
            print("\n  !! No eligible profile — needs replacement")
        elif not man:
            print(f"\n  → Awaiting manual assignment. Suggested: {sug}")

    # Summary
    no_eligible  = [s for s in SOURCE_WORDS if not all_eligible[s]]
    out_of_range = [s for s in SOURCE_WORDS
                    if manual.get(s) and manual[s] not in all_eligible.get(s, [])]
    pending      = [s for s in SOURCE_WORDS
                    if s not in manual and all_eligible.get(s)]

    print(f"\n{'=' * 64}")
    print(f"Summary: {len(SOURCE_WORDS)} source words  |  "
          f"{len(manual)} manual  |  {len(pending)} pending")
    if no_eligible:
        print(f"\n  ✗ No eligible profile (replace these):")
        for s in no_eligible:
            counts_str = "  ".join(f"{p[3:6]}={len(all_required[s][p])}"
                                   for p in PROFILE_ORDER)
            print(f"    {s:<16}  {counts_str}")
    if out_of_range:
        print(f"\n  ⚠ Manual assignment out of range:")
        for s in out_of_range:
            el_str = ", ".join(all_eligible[s]) or "none"
            print(f"    {s:<16}  manual={manual[s]}  eligible=[{el_str}]")
    if pending:
        print(f"\n  Pending manual assignments:")
        for s in pending:
            sug = suggest_profile(all_eligible[s], all_required[s], targets)
            print(f"    {s:<16}  suggested: {sug}")
    print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Calibrate Russian level generator profiles.")
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

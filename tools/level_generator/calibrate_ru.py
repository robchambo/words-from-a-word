"""
Global vocabulary calibration for the Russian level generator.

Two-phase tool:

  Phase 1 — Global vocabulary build
    Runs the full ru_freq.txt through the same quality gate as generate_ru.py
    (formability is skipped — we want all valid lemmas, not just those
    formable from a specific source word). Caches the resulting set of
    (word, count) pairs to vocab_cache_ru.json. This is the expensive step
    (~1–2 min on first run); subsequent runs load from cache in seconds.

    After building the cache, prints vocabulary frequency distribution
    statistics and suggests freq_threshold percentile cutoffs. Use these
    to inform PROFILES values in generate_ru.py that remain stable as new
    source words are added — thresholds anchored to the global vocabulary
    distribution do not drift when the source word set changes.

  Phase 2 — Source word evaluation
    For each source word in SOURCE_WORDS, filters the global vocab cache
    to words formable from that source word's letters, then counts how many
    would be classified as required under each profile. Prints the same
    required-word count table as before.

    Target: each source word should land 7–13 required words at its
    assigned profile (best-fit closest to 10).

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
import os
import sys
import time
import io
import generate_ru as g

CACHE_FILE = os.path.join(g.SCRIPT_DIR, 'vocab_cache_ru.json')

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

def print_distribution_stats(vocab):
    """
    Prints frequency distribution of the global vocab and suggests
    freq_threshold cutoffs at key percentile points.

    Use these to set stable PROFILES values in generate_ru.py. Percentile-
    anchored thresholds remain valid as the source word set grows, because
    they describe the vocabulary distribution, not the current source words.
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
    print("Suggested freq_threshold values (words BELOW this go to bonus):")
    for p in [10, 20, 30, 40, 50]:
        idx = int((p / 100) * n)
        idx = max(0, min(idx, n - 1))
        # freq_threshold: bottom p% of vocab goes to bonus
        cutoff = counts[-(idx+1)] if idx < n else counts[-1]
        print(f"  bottom {p:2d}% → freq_threshold ~{cutoff:>8,}")


# ---------------------------------------------------------------------------
# Phase 2 — source word evaluation
# ---------------------------------------------------------------------------

def build_candidates_from_vocab(source_word, vocab):
    """
    Filters the global vocab to words formable from source_word's letters
    and shorter than source_word. Returns list of (word, count).
    """
    src_counts = g.letter_counts(source_word.lower())
    src_len = len(source_word)
    return [
        (word, count) for word, count in vocab
        if len(word) < src_len and g.can_form(word, src_counts)
    ]


def count_required(candidates, max_length, freq_threshold, max_freq):
    """Count words that would be classified as required under a profile."""
    n = 0
    for word, count in candidates:
        if count >= max_freq:
            continue
        if len(word) <= max_length and count >= freq_threshold:
            n += 1
    return n


def print_source_word_table(vocab):
    print("Building candidate sets from global vocab...")
    t0 = time.time()
    candidates_by_src = {}
    for src in SOURCE_WORDS:
        cands = build_candidates_from_vocab(src, vocab)
        candidates_by_src[src] = cands
        print(f"  {src:<16} {len(cands):>4} candidates")
    print(f"  ({time.time()-t0:.1f}s)")

    print()
    header = f"{'source word':<16} " + " ".join(f"{p[3:6]:>5}" for p in PROFILE_ORDER) + "   best fit"
    print(header)
    print("-" * len(header))

    assignments = {}
    band_counts = {p: 0 for p in PROFILE_ORDER}
    in_band_total = 0

    for src in SOURCE_WORDS:
        cands = candidates_by_src[src]
        counts_per_profile = {
            p: count_required(cands, **g.PROFILES[p]) for p in PROFILE_ORDER
        }
        best = min(PROFILE_ORDER,
                   key=lambda p: (abs(counts_per_profile[p] - 10), PROFILE_ORDER.index(p)))
        assignments[src] = (best, counts_per_profile[best])
        band_counts[best] += 1
        if 7 <= counts_per_profile[best] <= 13:
            in_band_total += 1

        cells = " ".join(f"{counts_per_profile[p]:>5}" for p in PROFILE_ORDER)
        in_band = "OK" if 7 <= counts_per_profile[best] <= 13 else "--"
        print(f"{src:<16} {cells}   {best} ({counts_per_profile[best]}) {in_band}")

    print()
    print(f"In band (7-13 required words): {in_band_total} / {len(SOURCE_WORDS)}")
    print()
    print("Profile distribution:")
    for p in PROFILE_ORDER:
        print(f"  {p}: {band_counts[p]} levels")
    print()
    print("Suggested level function profile assignments:")
    for src, (profile, count) in assignments.items():
        print(f"    {src}: '{profile}'  # {count} required")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Calibrate Russian level generator profiles.")
    parser.add_argument('--rebuild', action='store_true',
                        help='Force rebuild the global vocab cache.')
    args = parser.parse_args()

    freq = g.load_freq(g.FREQ_FILE)
    blocklists = g.load_blocklist(g.BLOCKLIST_FILE)

    vocab = load_or_build_vocab(freq, blocklists, force_rebuild=args.rebuild)

    print_distribution_stats(vocab)
    print_source_word_table(vocab)


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    main()

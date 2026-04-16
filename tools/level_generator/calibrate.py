"""
Profile calibration for the Russian level generator.

For each Russian source word, runs the expensive filters (formability,
hunspell, pymorphy3 lemma + POS) ONCE to build a candidate set, then sweeps
the 5 seeded profiles cheaply over those candidates. Prints a table of
required-word counts per (source_word, profile) to inform tuning of PROFILES
in generate.py.

Production generate.py is not modified — this script duplicates its
inner-loop filtering for sweep efficiency.

Target: each source word should land 7–13 required words at its assigned
profile (best-fit closest to 10).

Re-run this script whenever:
  - A new source word is being evaluated for a level
  - PROFILES values are being adjusted
  - A TODO source word is being replaced

See calibrate_en.py for the equivalent English calibration tool.

Usage:
    py calibrate.py
"""

import time
import generate as g

SOURCE_WORDS = [
    "строитель", "государство", "воображение", "воспитание", "сотрудник",
    "правительство", "достижение", "архитектура", "библиотека", "холодильник",
    "университет", "расстояние", "переводчик", "образование", "произведение",
    "телевизор", "приключение", "картошка", "направление",
    "литература", "комсомолец",
    "математика", "территория",
]

PROFILE_ORDER = ['P1_BEGINNER', 'P2_EASY', 'P3_MEDIUM', 'P4_HARD', 'P5_EXPERT']


def build_candidates(source_word, freq, blocklists):
    """
    Mirror of generate.generate_level()'s expensive inner loop, but returns
    the (word, count) candidate set rather than classifying it.
    Profile-band classification is then a cheap second pass.
    """
    src = source_word.lower()
    src_counts = g.letter_counts(src)

    candidates = []
    blocked = []
    for word, count in freq.items():
        if len(word) < g.MIN_WORD_LENGTH or len(word) >= len(src):
            continue
        if not g.can_form(word, src_counts):
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
        if parsed[0].tag.POS == 'PREP':
            continue

        if word in blocklists.profanity:
            continue
        if word in blocklists.noise:
            blocked.append(word)
            continue
        candidates.append((word, count))
    return candidates


def count_required(candidates, max_length, freq_threshold, max_freq):
    n = 0
    for word, count in candidates:
        if count >= max_freq:
            continue
        if len(word) <= max_length and count >= freq_threshold:
            n += 1
    return n


def main():
    freq = g.load_freq(g.FREQ_FILE)
    blocklists = g.load_blocklist(g.BLOCKLIST_FILE)

    print()
    print("Building candidate sets (one expensive pass per source word)...")
    candidates_by_src = {}
    t0 = time.time()
    for src in SOURCE_WORDS:
        cands = build_candidates(src, freq, blocklists)
        candidates_by_src[src] = cands
        print(f"  {src:<16} {len(cands):>4} candidates  ({time.time()-t0:.1f}s)")
    print(f"Total candidate-build time: {time.time()-t0:.1f}s")

    print()
    header = f"{'source word':<16} " + " ".join(f"{p[3:6]:>5}" for p in PROFILE_ORDER) + "   best fit"
    print(header)
    print("-" * len(header))

    assignments = {}
    band_counts = {p: 0 for p in PROFILE_ORDER}
    in_band_total = 0

    for src in SOURCE_WORDS:
        cands = candidates_by_src[src]
        counts_per_profile = {p: count_required(cands, **g.PROFILES[p]) for p in PROFILE_ORDER}

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


if __name__ == '__main__':
    import io, sys
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    main()

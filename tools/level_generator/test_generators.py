"""
Tests for the Russian (generate.py) and English (generate_en.py) generators.

Covers pure functions that don't require hunspell dictionaries at runtime:
  - letter_counts / can_form
  - load_freq (with fixture)
  - load_blocklist (with fixture)
  - PROFILES structure
  - Russian: get_lemma
  - English: get_lemma_en

Hunspell-dependent tests are gated with @pytest.mark.skipif so the suite
runs cleanly on machines missing en_US or ru_RU dictionaries.

Run with:
    pytest test_generators.py -v
"""

import os
import pytest
import enchant


def _dict_available(code):
    try:
        enchant.Dict(code)
        return True
    except enchant.errors.DictNotFoundError:
        return False


EN_AVAILABLE = _dict_available('en_US')
RU_AVAILABLE = _dict_available('ru_RU')


# ---------------------------------------------------------------------------
# Imports gated on dictionary availability
# ---------------------------------------------------------------------------

if EN_AVAILABLE:
    import generate_en

if RU_AVAILABLE:
    import generate


# ---------------------------------------------------------------------------
# Russian pure-function tests
# ---------------------------------------------------------------------------

@pytest.mark.skipif(not RU_AVAILABLE, reason="ru_RU hunspell dictionary not available")
class TestRussianPureFunctions:
    def test_letter_counts_basic(self):
        assert generate.letter_counts("кот") == {'к': 1, 'о': 1, 'т': 1}

    def test_letter_counts_empty(self):
        assert generate.letter_counts("") == {}

    def test_can_form_true(self):
        src = generate.letter_counts("строитель")
        assert generate.can_form("три", src) is True

    def test_can_form_false_missing_letter(self):
        src = generate.letter_counts("кот")
        assert generate.can_form("кит", src) is False  # no 'и' in 'кот'

    def test_can_form_false_not_enough_of_letter(self):
        src = generate.letter_counts("кот")  # only one 'о'
        assert generate.can_form("тоо", src) is False

    def test_profiles_have_required_keys(self):
        for name, profile in generate.PROFILES.items():
            assert set(profile.keys()) == {'freq_threshold', 'max_freq', 'max_length'}, name
            assert profile['freq_threshold'] < profile['max_freq'], name
            assert profile['max_length'] >= generate.MIN_WORD_LENGTH, name

    def test_profile_difficulty_mapping_complete(self):
        for name in generate.PROFILES:
            assert name in generate.PROFILE_DIFFICULTY

    def test_get_lemma_returns_self_for_nominative_noun(self):
        # кот is already nominative singular — should pass through unchanged
        assert generate.get_lemma("кот") == "кот"

    def test_get_lemma_reduces_genitive_noun(self):
        # кота (genitive singular) → nominative singular кот
        assert generate.get_lemma("кота") == "кот"

    def test_get_lemma_returns_infinitive_for_verb(self):
        # идёт (3rd person present) → infinitive идти
        assert generate.get_lemma("идёт") == "идти"

    def test_get_lemma_returns_short_adj_form(self):
        # красивый (full adjective) → short masculine form красив
        assert generate.get_lemma("красивый") == "красив"


# ---------------------------------------------------------------------------
# English pure-function tests
# ---------------------------------------------------------------------------

@pytest.mark.skipif(not EN_AVAILABLE, reason="en_US hunspell dictionary not available")
class TestEnglishPureFunctions:
    def test_letter_counts_basic(self):
        assert generate_en.letter_counts("breakfast") == {
            'b': 1, 'r': 1, 'e': 1, 'a': 2, 'k': 1, 'f': 1, 's': 1, 't': 1
        }

    def test_letter_counts_empty(self):
        assert generate_en.letter_counts("") == {}

    def test_can_form_true(self):
        src = generate_en.letter_counts("breakfast")
        assert generate_en.can_form("beat", src) is True
        assert generate_en.can_form("safe", src) is True

    def test_can_form_false_missing_letter(self):
        src = generate_en.letter_counts("breakfast")
        assert generate_en.can_form("zone", src) is False

    def test_can_form_false_not_enough_of_letter(self):
        src = generate_en.letter_counts("breakfast")  # only one 'b'
        assert generate_en.can_form("babe", src) is False

    def test_profiles_have_required_keys(self):
        for name, profile in generate_en.PROFILES.items():
            assert set(profile.keys()) == {'freq_threshold', 'max_freq', 'max_length'}, name
            assert profile['freq_threshold'] < profile['max_freq'], name
            assert profile['max_length'] >= generate_en.MIN_WORD_LENGTH, name

    def test_profile_difficulty_mapping_complete(self):
        for name in generate_en.PROFILES:
            assert name in generate_en.PROFILE_DIFFICULTY

    def test_get_lemma_en_returns_self_for_base_forms(self):
        assert generate_en.get_lemma_en("run") == "run"
        assert generate_en.get_lemma_en("house") == "house"
        assert generate_en.get_lemma_en("eat") == "eat"

    def test_get_lemma_en_reduces_plural_noun(self):
        assert generate_en.get_lemma_en("houses") != "houses"  # → "house"

    def test_get_lemma_en_reduces_verb_inflection(self):
        assert generate_en.get_lemma_en("running") != "running"  # → "run"


# ---------------------------------------------------------------------------
# Fixture-based tests for load_freq and load_blocklist.
# These don't require hunspell — they test pure file-loading logic shared by
# both generators. The fixture picks whichever module is importable.
# ---------------------------------------------------------------------------

@pytest.fixture
def generator_module():
    if EN_AVAILABLE:
        return generate_en
    if RU_AVAILABLE:
        return generate
    pytest.skip("No generator module importable without its hunspell dict")


def test_load_freq_skips_comments_and_noise(generator_module, tmp_path):
    # English module uses a LATIN regex; Russian uses CYRILLIC.
    # Use matching data for whichever module the fixture returned.
    is_english = hasattr(generator_module, 'LATIN')
    if is_english:
        content = "# comment\nhello 1000\nworld 500\n123 42\n"
        expected = {'hello': 1000, 'world': 500}
    else:
        content = "# comment\nдом 1000\nкот 500\n123 42\n"
        expected = {'дом': 1000, 'кот': 500}
    p = tmp_path / "freq.txt"
    p.write_text(content, encoding='utf-8')
    freq = generator_module.load_freq(str(p))
    assert freq == expected


def test_load_blocklist_section_aware(generator_module, tmp_path):
    content = (
        "# header\n"
        "# === SECTION 1: NOISE ===\n"
        "noise1\n"
        "noise2\n"
        "\n"
        "# === SECTION 2: PROFANITY ===\n"
        "bad1\n"
        "bad2\n"
    )
    p = tmp_path / "blocklist.txt"
    p.write_text(content, encoding='utf-8')
    bl = generator_module.load_blocklist(str(p))
    assert bl.noise == {'noise1', 'noise2'}
    assert bl.profanity == {'bad1', 'bad2'}


def test_load_blocklist_missing_file_returns_empty(generator_module, tmp_path):
    bl = generator_module.load_blocklist(str(tmp_path / 'missing.txt'))
    assert bl.noise == set()
    assert bl.profanity == set()

"""
Tests for the Russian (generate.py) and English (generate_en.py) generators.

Covers pure functions that don't require hunspell dictionaries at runtime:
  - letter_counts / can_form
  - load_freq (with fixture)
  - load_blocklist (with fixture)
  - PROFILES structure
  - English-specific: is_base_form

Hunspell-dependent integration tests are gated with @pytest.mark.skipif
so the suite runs cleanly on machines missing en_US or ru_RU dictionaries.

Run with:
    pytest test_generators.py -v
"""

import os
import tempfile
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
# Shared pure-function tests — run for whichever generators have their dict.
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

    def test_is_base_form_accepts_lemmas(self):
        assert generate_en.is_base_form("run") is True
        assert generate_en.is_base_form("eat") is True
        assert generate_en.is_base_form("house") is True

    def test_is_base_form_rejects_inflections(self):
        assert generate_en.is_base_form("running") is False
        assert generate_en.is_base_form("eating") is False
        assert generate_en.is_base_form("houses") is False


@pytest.mark.skipif(not RU_AVAILABLE, reason="ru_RU hunspell dictionary not available")
class TestRussianPureFunctions:
    def test_letter_counts_basic(self):
        assert generate.letter_counts("кот") == {'к': 1, 'о': 1, 'т': 1}

    def test_can_form_true(self):
        src = generate.letter_counts("строитель")
        assert generate.can_form("три", src) is True

    def test_can_form_false(self):
        src = generate.letter_counts("кот")
        assert generate.can_form("кит", src) is False  # no 'и' in 'кот'

    def test_profiles_have_required_keys(self):
        for name, profile in generate.PROFILES.items():
            assert set(profile.keys()) == {'freq_threshold', 'max_freq', 'max_length'}, name
            assert profile['freq_threshold'] < profile['max_freq'], name

    def test_profile_difficulty_mapping_complete(self):
        for name in generate.PROFILES:
            assert name in generate.PROFILE_DIFFICULTY


# ---------------------------------------------------------------------------
# Fixture-based tests for load_freq and load_blocklist.
# These don't need hunspell at all — import the generators lazily via
# whichever is available (they share these function signatures).
# ---------------------------------------------------------------------------

@pytest.fixture
def generator_module():
    if EN_AVAILABLE:
        return generate_en
    if RU_AVAILABLE:
        return generate
    pytest.skip("No generator module importable without its hunspell dict")


def test_load_freq_skips_comments_and_noise(generator_module, tmp_path):
    # The English loader uses LATIN regex; the Russian loader uses CYRILLIC.
    # We pick data matching whichever module is in play.
    if generator_module is generate_en if EN_AVAILABLE else False:
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

"""
One-time setup for the level generator.

Run after `pip install -r requirements.txt`:

    python bootstrap.py

Downloads NLTK corpora the English generator needs and verifies that
pyenchant can resolve the en_US and ru_RU hunspell dictionaries.
"""

import sys

print("Downloading NLTK corpora...")
import nltk
for pkg in ['wordnet', 'averaged_perceptron_tagger_eng']:
    nltk.download(pkg, quiet=True)
print("  done.")

print("Verifying pyenchant dictionaries...")
import enchant
missing = []
for code in ['en_US', 'ru_RU']:
    try:
        d = enchant.Dict(code)
        d.check('test')
        print(f"  {code}: OK")
    except enchant.errors.DictNotFoundError:
        print(f"  {code}: MISSING")
        missing.append(code)

print()
if missing:
    print(f"Missing hunspell dictionaries: {', '.join(missing)}")
    print("Each generator that needs a missing dict will fail at runtime.")
    print("To install LibreOffice dictionaries:")
    print("  https://github.com/LibreOffice/dictionaries")
    print("Place .dic and .aff files where pyenchant can find them, or set PYENCHANT_LIBRARY_PATH.")
    print()
print("Bootstrap complete.")

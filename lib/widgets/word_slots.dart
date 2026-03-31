import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/language_mode.dart';
import '../l10n/strings_ru.dart';
import '../l10n/strings_en.dart';
import '../theme/app_theme.dart';
import 'word_slot_item.dart';

class WordSlots extends StatelessWidget {
  final List<TargetWord> targetWords;
  final LanguageMode languageMode;
  final String? lastFoundWord;

  const WordSlots({
    super.key,
    required this.targetWords,
    required this.languageMode,
    this.lastFoundWord,
  });

  @override
  Widget build(BuildContext context) {
    // Group non-bonus words by length
    final nonBonus = targetWords.where((w) => !w.isBonus).toList();
    final grouped = <int, List<TargetWord>>{};
    for (final w in nonBonus) {
      grouped.putIfAbsent(w.length, () => []).add(w);
    }
    final sortedLengths = grouped.keys.toList()..sort();

    // Bonus words
    final bonusWords = targetWords.where((w) => w.isBonus).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final length in sortedLengths) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
            child: Text(
              languageMode == LanguageMode.russian
                  ? StringsRu.lettersHeader(length)
                  : StringsEn.lettersHeader(length),
              style: AppTheme.condensedLabel,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: grouped[length]!.map((tw) {
                return WordSlotItem(
                  targetWord: tw,
                  justFound: lastFoundWord == tw.word,
                );
              }).toList(),
            ),
          ),
        ],
        if (bonusWords.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
            child: Text(
              languageMode == LanguageMode.russian
                  ? StringsRu.bonusLabel.toUpperCase()
                  : StringsEn.bonusLabel.toUpperCase(),
              style: AppTheme.condensedLabel.copyWith(
                color: AppTheme.accent,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: bonusWords.map((tw) {
                return WordSlotItem(
                  targetWord: tw,
                  justFound: lastFoundWord == tw.word,
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

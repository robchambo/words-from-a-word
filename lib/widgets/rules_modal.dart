import 'package:flutter/material.dart';

import '../models/language_mode.dart';
import '../l10n/strings_ru.dart';
import '../l10n/strings_en.dart';
import '../theme/app_theme.dart';

class RulesModal extends StatelessWidget {
  final LanguageMode languageMode;

  const RulesModal({super.key, required this.languageMode});

  bool get _isRu => languageMode == LanguageMode.russian;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            _isRu ? StringsRu.rulesTitle : StringsEn.rulesTitle,
            style: AppTheme.displayMedium,
          ),
          const SizedBox(height: 16),
          _ruleItem(_isRu ? StringsRu.rulesGoal : StringsEn.rulesGoal),
          _ruleItem(_isRu ? StringsRu.rulesHow : StringsEn.rulesHow),
          _ruleItem(_isRu ? StringsRu.rulesRules : StringsEn.rulesRules),
          _ruleItem(_isRu ? StringsRu.rulesHint : StringsEn.rulesHint),
          _ruleItem(_isRu ? StringsRu.rulesScore : StringsEn.rulesScore),
          _ruleItem(
              _isRu ? StringsRu.rulesComplete : StringsEn.rulesComplete),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                _isRu ? StringsRu.rulesClose : StringsEn.rulesClose,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _ruleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: AppTheme.condensedBold.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/settings_provider.dart';
import '../services/purchases_service.dart';
import '../theme/app_theme.dart';

/// Shows the hint-pack IAP pitch as a bottom sheet. Resolves when the sheet
/// closes (either via Buy or Cancel).
Future<void> showHintPackPitch(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.background,
    isScrollControlled: true,
    builder: (_) => const _HintPackPitchSheet(),
  );
}

class _HintPackPitchSheet extends StatelessWidget {
  const _HintPackPitchSheet();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isRussian = settings.languageMode == LanguageMode.russian;

    final title = isRussian
        ? StringsRu.hintPackPitchTitle
        : StringsEn.hintPackPitchTitle;
    final body = isRussian
        ? StringsRu.hintPackPitchBody
        : StringsEn.hintPackPitchBody;
    final buy =
        isRussian ? StringsRu.hintPackPitchBuy : StringsEn.hintPackPitchBuy;
    final cancel = isRussian
        ? StringsRu.hintPackPitchCancel
        : StringsEn.hintPackPitchCancel;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppTheme.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: AppTheme.condensedBold.copyWith(
                fontWeight: FontWeight.w400,
                fontSize: 16,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('hint_pack_pitch.buy'),
              onPressed: () async {
                await PurchasesService.instance.buyHintPack();
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(buy),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('hint_pack_pitch.cancel'),
              onPressed: () => Navigator.pop(context),
              child: Text(
                cancel,
                style: AppTheme.condensedBold.copyWith(
                  color: AppTheme.mutedFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

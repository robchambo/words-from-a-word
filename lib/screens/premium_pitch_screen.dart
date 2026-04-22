import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/settings_provider.dart';
import '../services/purchases_service.dart';
import '../theme/app_theme.dart';
import '../widgets/grid_paper_background.dart';

/// Full-screen pitch for the "Remove ads" non-consumable IAP.
class PremiumPitchScreen extends StatelessWidget {
  const PremiumPitchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isRussian = settings.languageMode == LanguageMode.russian;

    final title =
        isRussian ? StringsRu.premiumPitchTitle : StringsEn.premiumPitchTitle;
    final body =
        isRussian ? StringsRu.premiumPitchBody : StringsEn.premiumPitchBody;
    final buy =
        isRussian ? StringsRu.premiumPitchBuy : StringsEn.premiumPitchBuy;
    final notNow = isRussian
        ? StringsRu.premiumPitchNotNow
        : StringsEn.premiumPitchNotNow;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.foreground),
      ),
      body: GridPaperBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Text(
                  title,
                  style: AppTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  body,
                  style: AppTheme.condensedBold.copyWith(
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                ElevatedButton(
                  key: const Key('premium_pitch.buy'),
                  onPressed: () async {
                    await PurchasesService.instance.buyPremium();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(buy),
                ),
                const SizedBox(height: 12),
                TextButton(
                  key: const Key('premium_pitch.not_now'),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    notNow,
                    style: AppTheme.condensedBold.copyWith(
                      color: AppTheme.mutedFg,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

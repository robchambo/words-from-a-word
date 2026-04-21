import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/grid_paper_background.dart';
import '../widgets/rules_modal.dart';
import '../widgets/settings_row.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isRussian = settings.languageMode == LanguageMode.russian;

    final title =
        isRussian ? StringsRu.settingsTitle : StringsEn.settingsTitle;
    final langLabel =
        isRussian ? StringsRu.settingsLanguage : StringsEn.settingsLanguage;
    final rulesLabel =
        isRussian ? StringsRu.settingsRules : StringsEn.settingsRules;
    final muteLabel =
        isRussian ? StringsRu.settingsMute : StringsEn.settingsMute;
    final removeAdsLabel =
        isRussian ? StringsRu.settingsRemoveAds : StringsEn.settingsRemoveAds;
    final restoreLabel =
        isRussian ? StringsRu.settingsRestore : StringsEn.settingsRestore;
    final privacyLabel =
        isRussian ? StringsRu.settingsPrivacy : StringsEn.settingsPrivacy;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.foreground),
        title: Text(title, style: AppTheme.condensedBold),
      ),
      body: GridPaperBackground(
        child: SafeArea(
          child: ListView(
            children: [
              SettingsRow(
                label: langLabel,
                onTap: () => _openLanguageSheet(context, settings),
                trailing: Text(
                  settings.languageMode.displayName,
                  style: AppTheme.condensedLabel,
                ),
              ),
              SettingsRow(
                label: rulesLabel,
                onTap: () => _openRulesModal(context, settings),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppTheme.foreground,
                ),
              ),
              // Phase 1 disabled; Phase 4 enables.
              SettingsRow(
                label: muteLabel,
                enabled: false,
                trailing: Switch(value: settings.muted, onChanged: null),
              ),
              // Phase 5 enables.
              SettingsRow(
                label: removeAdsLabel,
                enabled: false,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppTheme.foreground,
                ),
              ),
              SettingsRow(
                label: restoreLabel,
                enabled: false,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppTheme.foreground,
                ),
              ),
              SettingsRow(
                label: privacyLabel,
                enabled: false,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppTheme.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRulesModal(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      isScrollControlled: true,
      builder: (_) => RulesModal(languageMode: settings.languageMode),
    );
  }

  void _openLanguageSheet(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in LanguageMode.values)
              ListTile(
                title: Text(mode.displayName),
                leading: Text(
                  mode.flagEmoji,
                  style: const TextStyle(fontSize: 22),
                ),
                onTap: () async {
                  await settings.setLanguageMode(mode);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

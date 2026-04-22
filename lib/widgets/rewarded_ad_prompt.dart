import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/settings_provider.dart';

/// Shows a rewarded-ad prompt asking the user whether they want to watch a
/// short video in exchange for one hint. Returns `true` if the user tapped
/// Watch, `false` for No thanks or barrier dismiss.
Future<bool> showRewardedAdPrompt(BuildContext context) async {
  final settings = context.read<SettingsProvider>();
  final isRu = (settings.languageMode ?? LanguageMode.russian) ==
      LanguageMode.russian;

  final title =
      isRu ? StringsRu.rewardedAdPromptTitle : StringsEn.rewardedAdPromptTitle;
  final body =
      isRu ? StringsRu.rewardedAdPromptBody : StringsEn.rewardedAdPromptBody;
  final watch =
      isRu ? StringsRu.rewardedAdPromptWatch : StringsEn.rewardedAdPromptWatch;
  final no = isRu ? StringsRu.rewardedAdPromptNo : StringsEn.rewardedAdPromptNo;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(no),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(watch),
        ),
      ],
    ),
  );

  return result ?? false;
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A single row in the settings screen. Styled per Soviet-Notebook design:
/// navy label on cream, optional trailing widget (switch or chevron),
/// optional onTap. If [enabled] is false, the whole row is dimmed and taps
/// are swallowed.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTheme.condensedBold.copyWith(
                color: enabled ? AppTheme.foreground : AppTheme.muted,
              ),
            ),
          ),
          trailing ?? const SizedBox(),
        ],
      ),
    );

    if (!enabled || onTap == null) {
      return Opacity(opacity: enabled ? 1 : 0.5, child: content);
    }

    return InkWell(
      onTap: onTap,
      child: Semantics(button: true, label: label, child: content),
    );
  }
}

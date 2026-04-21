import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/rewards_provider.dart';
import '../theme/app_theme.dart';

class FreeHintEarnedOverlay extends StatefulWidget {
  final LanguageMode mode;
  const FreeHintEarnedOverlay({super.key, required this.mode});

  @override
  State<FreeHintEarnedOverlay> createState() => _FreeHintEarnedOverlayState();
}

class _FreeHintEarnedOverlayState extends State<FreeHintEarnedOverlay> {
  bool _show = false;
  int _lastTick = 0;
  RewardsProvider? _rewards;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = context.read<RewardsProvider>();
    if (identical(_rewards, r)) return;
    _rewards?.freeHintEarnedTicks.removeListener(_onTick);
    _rewards = r;
    _lastTick = r.freeHintEarnedTicks.value;
    r.freeHintEarnedTicks.addListener(_onTick);
  }

  @override
  void dispose() {
    _rewards?.freeHintEarnedTicks.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    final v = _rewards!.freeHintEarnedTicks.value;
    if (v > _lastTick) {
      _lastTick = v;
      if (!mounted) return;
      setState(() => _show = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _show = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final isRu = widget.mode == LanguageMode.russian;
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _show = false),
        child: Container(
          color: AppTheme.foreground.withValues(alpha: 0.4),
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lightbulb, color: AppTheme.accent, size: 48),
                const SizedBox(height: 12),
                Text(
                  isRu
                      ? StringsRu.freeHintEarnedTitle
                      : StringsEn.freeHintEarnedTitle,
                  style: AppTheme.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  isRu
                      ? StringsRu.freeHintEarnedBody
                      : StringsEn.freeHintEarnedBody,
                  style: AppTheme.condensedBold,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 200.ms).scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.0, 1.0),
            ),
      ),
    );
  }
}

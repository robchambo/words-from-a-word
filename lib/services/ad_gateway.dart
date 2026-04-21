import 'package:flutter/foundation.dart';

/// Where a hint came from when `RewardsProvider.consumeHint()` succeeded.
enum HintSource { freeSlot, purchased, rewardedAd }

/// Abstraction over ad network SDKs. Swapped from [NoopAdGateway] to
/// MobileAdsGateway in Phase 5. Consumers read this via
/// `context.read<AdGateway>()`.
abstract class AdGateway {
  Future<void> initialize();
  Future<void> loadInterstitial();

  /// Returns true if an interstitial was shown.
  Future<bool> showInterstitial();

  Future<void> loadRewarded();

  /// Calls [onReward] if the user watched to completion. Returns true if the
  /// ad played at all (even if the user abandoned partway).
  Future<bool> showRewarded({required VoidCallback onReward});
}

/// Default, development-safe implementation. Logs intent, reward-grants
/// immediately, never shows anything real.
class NoopAdGateway implements AdGateway {
  @override
  Future<void> initialize() async {
    debugPrint('[NoopAdGateway] initialize');
  }

  @override
  Future<void> loadInterstitial() async {
    debugPrint('[NoopAdGateway] loadInterstitial');
  }

  @override
  Future<bool> showInterstitial() async {
    debugPrint('[NoopAdGateway] showInterstitial -> false');
    return false;
  }

  @override
  Future<void> loadRewarded() async {
    debugPrint('[NoopAdGateway] loadRewarded');
  }

  @override
  Future<bool> showRewarded({required VoidCallback onReward}) async {
    debugPrint('[NoopAdGateway] showRewarded -> grant immediately');
    onReward();
    return true;
  }
}

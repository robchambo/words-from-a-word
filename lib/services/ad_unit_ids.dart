import 'dart:io' show Platform;

/// Hard-coded Google test ad unit IDs. Phase 6 replaces these with
/// `RemoteConfigService` getters. Real AdMob IDs are entered in Phase 5
/// Task 12 once the AdMob account is set up, or from Remote Config after
/// Phase 6 ships.
class AdUnitIds {
  AdUnitIds._();

  static String get interstitial {
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/4411468910';
    return 'ca-app-pub-3940256099942544/1033173712';
  }

  static String get rewarded {
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/1712485313';
    return 'ca-app-pub-3940256099942544/5224354917';
  }
}

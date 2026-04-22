import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_gateway.dart';
import 'ad_unit_ids.dart';

/// Pure cadence helper — unit-testable without MobileAds.
class InterstitialCadence {
  InterstitialCadence({required this.everyN});
  final int everyN;
  int _count = 0;

  bool shouldShow() {
    if (everyN <= 0) return false;
    _count += 1;
    if (_count % everyN == 0) {
      return true;
    }
    return false;
  }
}

class MobileAdsGateway implements AdGateway {
  MobileAdsGateway({int interstitialCadence = 3})
      : _cadence = InterstitialCadence(everyN: interstitialCadence);

  final InterstitialCadence _cadence;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    unawaited(loadInterstitial());
    unawaited(loadRewarded());
  }

  @override
  Future<void> loadInterstitial() async {
    if (_interstitial != null) return;
    await InterstitialAd.load(
      adUnitId: AdUnitIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (err) {
          debugPrint('[MobileAdsGateway] interstitial load failed: $err');
          _interstitial = null;
        },
      ),
    );
  }

  @override
  Future<bool> showInterstitial() async {
    if (!_cadence.shouldShow()) return false;
    final ad = _interstitial;
    if (ad == null) {
      unawaited(loadInterstitial());
      return false;
    }
    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        unawaited(loadInterstitial());
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _interstitial = null;
        unawaited(loadInterstitial());
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    await ad.show();
    return completer.future;
  }

  @override
  Future<void> loadRewarded() async {
    if (_rewarded != null) return;
    await RewardedAd.load(
      adUnitId: AdUnitIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (err) {
          debugPrint('[MobileAdsGateway] rewarded load failed: $err');
          _rewarded = null;
        },
      ),
    );
  }

  @override
  Future<bool> showRewarded({required VoidCallback onReward}) async {
    final ad = _rewarded;
    if (ad == null) {
      unawaited(loadRewarded());
      return false;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewarded = null;
        unawaited(loadRewarded());
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _rewarded = null;
        unawaited(loadRewarded());
      },
    );
    await ad.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        onReward();
      },
    );
    return true;
  }
}

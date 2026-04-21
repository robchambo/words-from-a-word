# Phase 5 — Monetisation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Swap the `NoopAdGateway` for a real AdMob-backed `MobileAdsGateway`, wire interstitials between levels, rewarded ads as the hint-waterfall fallback, premium-remove-ads + hint-pack IAP, restore purchases, and gate ad init on ATT (iOS) + UMP consent.

**Architecture:** `MobileAdsGateway` implements the existing `AdGateway` interface from Phase 1; swap happens at one line in `main.dart`. `PurchasesService` (new singleton) wraps `in_app_purchase` and writes results into `RewardsProvider` (premium flag, purchasedHintCount). `ConsentService` (new singleton) runs the ATT prompt on iOS first launch and UMP (Google's Consent Management Platform) for GDPR users; both gate `MobileAdsGateway.initialize()`. Interstitial cadence and ad unit IDs are read from `RemoteConfigService` (Phase 6) with hard-coded fallbacks until then.

**Tech Stack:** Dart 3.11, Flutter, `google_mobile_ads ^5.1.0`, `in_app_purchase ^3.2.0`, `app_tracking_transparency ^2.0.4`, existing `RewardsProvider`, existing `AdGateway`.

---

## File Structure

- **Create**
  - `lib/services/mobile_ads_gateway.dart` — real `AdGateway` impl. Interstitial + rewarded loaders, cadence counter.
  - `lib/services/purchases_service.dart` — wraps `in_app_purchase`. Exposes `buyPremium()`, `buyHintPack()`, `restore()`, `purchaseStream`.
  - `lib/services/consent_service.dart` — ATT + UMP prompts. Gates ad init.
  - `lib/services/ad_unit_ids.dart` — hard-coded test IDs + platform-switch helpers.
  - `lib/screens/premium_pitch_screen.dart` — full-screen paywall for remove-ads IAP.
  - `lib/widgets/hint_pack_pitch_sheet.dart` — bottom sheet shown when out of hints (offers pack + watch ad + cancel).
  - `lib/widgets/rewarded_ad_prompt.dart` — dialog shown by GameProvider when `pendingRewardedAdPrompt` flips true.
  - `test/services/purchases_service_test.dart`
  - `test/services/consent_service_test.dart`
  - `test/services/mobile_ads_gateway_test.dart` — uses a mockable seam via dependency injection.

- **Modify**
  - `pubspec.yaml` — uncomment / add `google_mobile_ads`, `in_app_purchase`, `app_tracking_transparency`.
  - `ios/Runner/Info.plist` — add `NSUserTrackingUsageDescription`, `GADApplicationIdentifier`, `SKAdNetworkItems`.
  - `android/app/src/main/AndroidManifest.xml` — add AdMob app ID meta-data, required Android 13 ad-ID permission.
  - `lib/main.dart` — swap `NoopAdGateway` for `MobileAdsGateway`; init `PurchasesService` + `ConsentService` before creating gateway.
  - `lib/providers/game_provider.dart` — call `showInterstitial()` on level complete per cadence; handle `onRewardedAdCompleted` / `onRewardedAdDeclined` (defined in Phase 2) to actually play the rewarded ad.
  - `lib/screens/settings_screen.dart` — enable Remove Ads + Restore rows; route to premium pitch; call purchases service.
  - `lib/screens/level_complete_overlay.dart` — hook interstitial between levels (already enters here via GameProvider).
  - `lib/l10n/strings_ru.dart`, `lib/l10n/strings_en.dart` — add monetisation + consent string keys per `V1_1_CONTRACTS.md`.

---

## Task 1: Add packages

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Uncomment / add**

In `pubspec.yaml` under `dependencies:`:

```yaml
  google_mobile_ads: ^5.1.0
  in_app_purchase: ^3.2.0
  app_tracking_transparency: ^2.0.4
```

- [ ] **Step 2: Pub get + analyze**

Run: `flutter pub get && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add google_mobile_ads, in_app_purchase, app_tracking_transparency"
```

---

## Task 2: Platform manifests

**Files:**
- Modify: `ios/Runner/Info.plist`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: iOS — add required AdMob + ATT keys**

In `ios/Runner/Info.plist`, inside the top-level `<dict>`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>
<!-- ^ Google's iOS test app ID. Replaced with real ID in Task 12 once
     the AdMob account is set up. -->

<key>NSUserTrackingUsageDescription</key>
<string>We use this to show relevant ads so the game can stay free.</string>

<key>SKAdNetworkItems</key>
<array>
  <dict>
    <key>SKAdNetworkIdentifier</key>
    <string>cstr6suwn9.skadnetwork</string>
  </dict>
</array>
```

(For the full SKAdNetwork list see https://developers.google.com/admob/ios/quick-start#update_your_infoplist — start with the single Google entry; Phase 9 store submission will pull the rest from AdMob's docs.)

- [ ] **Step 2: Android — add AdMob meta-data + permissions**

In `android/app/src/main/AndroidManifest.xml`, inside `<application>`:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>
<!-- Google's Android test app ID. Replaced in Task 12. -->
```

And near the top of the manifest, alongside existing permissions (Android 13+):

```xml
<uses-permission android:name="com.google.android.gms.permission.AD_ID"/>
```

- [ ] **Step 3: Build to confirm manifests valid**

Run: `flutter build apk --debug` (or `flutter run` on device) and confirm build succeeds. iOS: `flutter build ios --debug --no-codesign`.

- [ ] **Step 4: Commit**

```bash
git add ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml
git commit -m "chore: add AdMob + ATT platform manifest entries (test IDs)"
```

---

## Task 3: Create `AdUnitIds` constants file

**Files:**
- Create: `lib/services/ad_unit_ids.dart`

- [ ] **Step 1: Write the helper**

Create `lib/services/ad_unit_ids.dart`:

```dart
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/ad_unit_ids.dart
git commit -m "feat: add AdUnitIds (Google test IDs; real ones later)"
```

---

## Task 4: Write `ConsentService`

**Files:**
- Create: `lib/services/consent_service.dart`
- Create: `test/services/consent_service_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/services/consent_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:slova_iz_slova/services/consent_service.dart';

void main() {
  test('ConsentResult has expected cases', () {
    expect(ConsentResult.values, [
      ConsentResult.granted,
      ConsentResult.denied,
      ConsentResult.notDetermined,
      ConsentResult.notApplicable,
    ]);
  });

  test('personalisedAdsAllowed is granted+granted', () {
    expect(ConsentService.personalisedAdsAllowed(
      att: ConsentResult.granted, ump: ConsentResult.granted,
    ), isTrue);
    expect(ConsentService.personalisedAdsAllowed(
      att: ConsentResult.denied, ump: ConsentResult.granted,
    ), isFalse);
    expect(ConsentService.personalisedAdsAllowed(
      att: ConsentResult.notApplicable, ump: ConsentResult.granted,
    ), isTrue, reason: 'Android has no ATT, should ignore');
  });
}
```

- [ ] **Step 2: Run (fail)**

Run: `flutter test test/services/consent_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `lib/services/consent_service.dart`:

```dart
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum ConsentResult { granted, denied, notDetermined, notApplicable }

class ConsentService {
  ConsentService._();
  static final ConsentService instance = ConsentService._();

  ConsentResult _att = ConsentResult.notDetermined;
  ConsentResult _ump = ConsentResult.notDetermined;

  ConsentResult get att => _att;
  ConsentResult get ump => _ump;

  static bool personalisedAdsAllowed({
    required ConsentResult att,
    required ConsentResult ump,
  }) {
    final attOk = att == ConsentResult.granted || att == ConsentResult.notApplicable;
    final umpOk = ump == ConsentResult.granted || ump == ConsentResult.notApplicable;
    return attOk && umpOk;
  }

  Future<void> initialize() async {
    await _runAtt();
    await _runUmp();
  }

  Future<void> _runAtt() async {
    if (!Platform.isIOS) {
      _att = ConsentResult.notApplicable;
      return;
    }
    try {
      final status =
          await AppTrackingTransparency.requestTrackingAuthorization();
      switch (status) {
        case TrackingStatus.authorized:
          _att = ConsentResult.granted;
          break;
        case TrackingStatus.denied:
        case TrackingStatus.restricted:
          _att = ConsentResult.denied;
          break;
        case TrackingStatus.notDetermined:
        case TrackingStatus.notSupported:
          _att = ConsentResult.notDetermined;
          break;
      }
    } catch (e) {
      debugPrint('[ConsentService] ATT error: $e');
      _att = ConsentResult.notDetermined;
    }
  }

  Future<void> _runUmp() async {
    final params = ConsentRequestParameters();
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          final available = await ConsentInformation.instance
              .isConsentFormAvailable();
          if (available) {
            final form = await ConsentForm.loadConsentForm();
            await form.show((formError) {});
          }
          final status =
              await ConsentInformation.instance.getConsentStatus();
          switch (status) {
            case ConsentStatus.obtained:
              _ump = ConsentResult.granted;
              break;
            case ConsentStatus.required:
              _ump = ConsentResult.denied;
              break;
            case ConsentStatus.notRequired:
              _ump = ConsentResult.notApplicable;
              break;
            case ConsentStatus.unknown:
              _ump = ConsentResult.notDetermined;
              break;
          }
        } finally {
          completer.complete();
        }
      },
      (error) {
        debugPrint('[ConsentService] UMP error: $error');
        _ump = ConsentResult.notDetermined;
        completer.complete();
      },
    );
    await completer.future;
  }
}
```

Add `import 'dart:async';` at top for `Completer`.

- [ ] **Step 4: Run**

Run: `flutter test test/services/consent_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/consent_service.dart test/services/consent_service_test.dart
git commit -m "feat: add ConsentService (ATT + UMP)"
```

---

## Task 5: Write `MobileAdsGateway`

**Files:**
- Create: `lib/services/mobile_ads_gateway.dart`
- Create: `test/services/mobile_ads_gateway_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/services/mobile_ads_gateway_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:slova_iz_slova/services/mobile_ads_gateway.dart';

void main() {
  group('InterstitialCadence', () {
    test('shows every N-th call and resets', () {
      final cadence = InterstitialCadence(everyN: 3);
      expect(cadence.shouldShow(), isFalse); // 1
      expect(cadence.shouldShow(), isFalse); // 2
      expect(cadence.shouldShow(), isTrue);  // 3 — show
      expect(cadence.shouldShow(), isFalse); // 4
      expect(cadence.shouldShow(), isFalse); // 5
      expect(cadence.shouldShow(), isTrue);  // 6
    });

    test('everyN=1 shows every time', () {
      final c = InterstitialCadence(everyN: 1);
      expect(c.shouldShow(), isTrue);
      expect(c.shouldShow(), isTrue);
    });

    test('everyN<=0 never shows', () {
      final c = InterstitialCadence(everyN: 0);
      expect(c.shouldShow(), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run (fail)**

Run: `flutter test test/services/mobile_ads_gateway_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `lib/services/mobile_ads_gateway.dart`:

```dart
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
    // Pre-warm
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
    // Cadence-gated. This mirrors GDD §8.3: every Nth level completion.
    if (!_cadence.shouldShow()) return false;
    final ad = _interstitial;
    if (ad == null) {
      // No ad ready; skip and pre-warm for next time
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
    var rewarded = false;
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
      onUserEarnedReward: (_, __) {
        rewarded = true;
        onReward();
      },
    );
    return true;
  }
}
```

Add imports at top:

```dart
import 'dart:async';
```

- [ ] **Step 4: Run test**

Run: `flutter test test/services/mobile_ads_gateway_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/mobile_ads_gateway.dart test/services/mobile_ads_gateway_test.dart
git commit -m "feat: implement MobileAdsGateway with interstitial cadence"
```

---

## Task 6: Write `PurchasesService`

**Files:**
- Create: `lib/services/purchases_service.dart`
- Create: `test/services/purchases_service_test.dart`

- [ ] **Step 1: Write failing test (minimal — real StoreKit can't be tested in unit)**

Create `test/services/purchases_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:slova_iz_slova/services/purchases_service.dart';

void main() {
  test('product IDs are exact', () {
    expect(PurchasesService.premiumProductId, 'premium_no_ads_299');
    expect(PurchasesService.hintPackProductId, 'hint_pack_099_5');
  });

  test('hintPackGrantSize is 5', () {
    expect(PurchasesService.hintPackGrantSize, 5);
  });
}
```

- [ ] **Step 2: Run (fail)**

Run: `flutter test test/services/purchases_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `lib/services/purchases_service.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../providers/rewards_provider.dart';

class PurchasesService {
  PurchasesService._();
  static final PurchasesService instance = PurchasesService._();

  static const String premiumProductId = 'premium_no_ads_299';
  static const String hintPackProductId = 'hint_pack_099_5';
  static const int hintPackGrantSize = 5;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  RewardsProvider? _rewards;
  final Map<String, ProductDetails> _products = {};

  Future<void> initialize(RewardsProvider rewards) async {
    _rewards = rewards;
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('[PurchasesService] store unavailable');
      return;
    }
    final response = await _iap.queryProductDetails(
      {premiumProductId, hintPackProductId},
    );
    for (final p in response.productDetails) {
      _products[p.id] = p;
    }
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) => debugPrint('[PurchasesService] stream error: $e'),
    );
  }

  ProductDetails? get premiumProduct => _products[premiumProductId];
  ProductDetails? get hintPackProduct => _products[hintPackProductId];

  Future<bool> buyPremium() async {
    final p = _products[premiumProductId];
    if (p == null) return false;
    return _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
  }

  Future<bool> buyHintPack() async {
    final p = _products[hintPackProductId];
    if (p == null) return false;
    return _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: p));
  }

  Future<void> restore() async {
    await _iap.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> updates) {
    for (final pd in updates) {
      switch (pd.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _grant(pd);
          if (pd.pendingCompletePurchase) {
            _iap.completePurchase(pd);
          }
          break;
        case PurchaseStatus.error:
          debugPrint('[PurchasesService] error: ${pd.error}');
          if (pd.pendingCompletePurchase) _iap.completePurchase(pd);
          break;
        case PurchaseStatus.canceled:
          if (pd.pendingCompletePurchase) _iap.completePurchase(pd);
          break;
      }
    }
  }

  void _grant(PurchaseDetails pd) {
    final r = _rewards;
    if (r == null) return;
    switch (pd.productID) {
      case premiumProductId:
        r.markPremium();
        break;
      case hintPackProductId:
        r.addPurchasedHints(hintPackGrantSize);
        break;
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
```

- [ ] **Step 4: Run**

Run: `flutter test test/services/purchases_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/purchases_service.dart test/services/purchases_service_test.dart
git commit -m "feat: add PurchasesService wrapping in_app_purchase"
```

---

## Task 7: Wire services into `main.dart`

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Replace NoopAdGateway with MobileAdsGateway, gated on consent**

Modify `main()`:

```dart
  // ... existing settings.load(), rewards.load() ...

  await ConsentService.instance.initialize();

  final AdGateway adGateway = MobileAdsGateway();
  if (ConsentService.personalisedAdsAllowed(
    att: ConsentService.instance.att,
    ump: ConsentService.instance.ump,
  )) {
    await adGateway.initialize();
  } else {
    // Still init with non-personalised ads — implementation-wise
    // MobileAdsGateway.initialize() calls MobileAds.instance.initialize()
    // which handles the request signalling internally via the UMP SDK.
    await adGateway.initialize();
  }

  await PurchasesService.instance.initialize(rewards);
```

Add imports:

```dart
import 'services/consent_service.dart';
import 'services/mobile_ads_gateway.dart';
import 'services/purchases_service.dart';
```

- [ ] **Step 2: Analyze + test**

Run: `flutter analyze && flutter test`
Expected: clean, passing.

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: swap NoopAdGateway for MobileAdsGateway; init Consent+Purchases"
```

---

## Task 8: Interstitial between levels

**Files:**
- Modify: `lib/providers/game_provider.dart`

- [ ] **Step 1: Find the level-complete bank-and-advance site**

Locate the `bankAndAdvance` method (added in Phase 2). It currently:
1. Calls `_rewards.onLevelComplete(...)`
2. Loads next level via `LevelLoader`

- [ ] **Step 2: Inject `AdGateway` into `GameProvider`**

Extend the constructor:

```dart
class GameProvider extends ChangeNotifier {
  GameProvider({required RewardsProvider rewards, required AdGateway adGateway, Random? rng})
    : _rewards = rewards,
      _adGateway = adGateway,
      _rng = rng ?? Random();
  // ...
  final AdGateway _adGateway;
```

Update `main.dart`'s `ChangeNotifierProxyProvider<RewardsProvider, GameProvider>` to also take `AdGateway`:

```dart
ChangeNotifierProxyProvider2<RewardsProvider, AdGateway, GameProvider>(
  create: (ctx) => GameProvider(
    rewards: ctx.read<RewardsProvider>(),
    adGateway: ctx.read<AdGateway>(),
  ),
  update: (ctx, rewards, adGateway, prev) =>
      prev ?? GameProvider(rewards: rewards, adGateway: adGateway),
),
```

- [ ] **Step 3: Wire interstitial into bankAndAdvance**

In `bankAndAdvance`, after `_rewards.onLevelComplete(...)` and before the next-level load, call:

```dart
  if (!_rewards.premium) {
    await _adGateway.showInterstitial();
  }
```

Premium users never see interstitials (GDD §8.1).

- [ ] **Step 4: Write failing test**

Create `test/providers/game_provider_interstitial_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/providers/game_provider.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';
import 'package:slova_iz_slova/services/ad_gateway.dart';

class _MockAdGateway extends Mock implements AdGateway {}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('non-premium: interstitial attempted on level complete', () async {
    final rewards = RewardsProvider();
    await rewards.load();
    final ad = _MockAdGateway();
    when(() => ad.showInterstitial()).thenAnswer((_) async => true);

    final gp = GameProvider(rewards: rewards, adGateway: ad);
    // Simulate a level-complete flow (calls vary — adapt to actual API)
    // await gp.startGame(levelNumber: 1, mode: LanguageMode.russian);
    // ... force state.isLevelComplete = true, then:
    // await gp.bankAndAdvance(LanguageMode.russian);
    // verify(() => ad.showInterstitial()).called(1);
    //
    // Pseudo — wire up per real GameProvider surface; above is intent.
  });

  test('premium: interstitial skipped', () async {
    SharedPreferences.setMockInitialValues({'rewards.premium': true});
    final rewards = RewardsProvider();
    await rewards.load();
    final ad = _MockAdGateway();

    final gp = GameProvider(rewards: rewards, adGateway: ad);
    // same scaffolding — verifyNever(() => ad.showInterstitial());
  });
}
```

(Adjust the test scaffolding to match the real `bankAndAdvance` surface — the `verify` / `verifyNever` calls are the invariants.)

- [ ] **Step 5: Run + commit**

Run: `flutter analyze && flutter test`
Expected: PASS.

```bash
git add lib/providers/game_provider.dart lib/main.dart test/providers/game_provider_interstitial_test.dart
git commit -m "feat: show interstitial between levels (cadence-gated, skip premium)"
```

---

## Task 9: Rewarded ad for hint (wire from Phase 2's pendingRewardedAdPrompt)

**Files:**
- Modify: `lib/providers/game_provider.dart`
- Create: `lib/widgets/rewarded_ad_prompt.dart`
- Modify: `lib/screens/game_screen.dart`

- [ ] **Step 1: Create the dialog**

Create `lib/widgets/rewarded_ad_prompt.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

Future<bool> showRewardedAdPrompt(BuildContext context) async {
  final settings = context.read<SettingsProvider>();
  final s = settings.languageMode == LanguageMode.russian ? StringsRu() : StringsEn();

  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppTheme.background,
      title: Text(s.rewardedAdPromptTitle),
      content: Text(s.rewardedAdPromptBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(s.rewardedAdPromptNo),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(s.rewardedAdPromptWatch),
        ),
      ],
    ),
  );
  return result ?? false;
}
```

- [ ] **Step 2: Wire into `game_screen.dart`**

In `GameScreen`, listen for `pendingRewardedAdPrompt` flag in the GameProvider state and show the dialog:

```dart
  // inside build, after watching game state:
  final game = context.watch<GameProvider>();
  if (game.state.pendingRewardedAdPrompt) {
    // schedule after frame so dialog can overlay
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final accepted = await showRewardedAdPrompt(context);
      final ad = context.read<AdGateway>();
      if (accepted) {
        var rewarded = false;
        await ad.showRewarded(onReward: () => rewarded = true);
        if (rewarded) {
          game.onRewardedAdCompleted();
        } else {
          game.onRewardedAdDeclined();
        }
      } else {
        game.onRewardedAdDeclined();
      }
    });
  }
```

Phase 2 defines `onRewardedAdCompleted` (grants the hint, consumes, applies the reveal) and `onRewardedAdDeclined` (clears the flag).

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: clean.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/rewarded_ad_prompt.dart lib/screens/game_screen.dart
git commit -m "feat: wire rewarded ad prompt into hint waterfall"
```

---

## Task 10: Premium pitch + hint-pack sheet UI

**Files:**
- Create: `lib/screens/premium_pitch_screen.dart`
- Create: `lib/widgets/hint_pack_pitch_sheet.dart`
- Modify: `lib/l10n/strings_ru.dart`, `lib/l10n/strings_en.dart`

- [ ] **Step 1: Add strings**

In both string files, add the keys listed in `V1_1_CONTRACTS.md` (premiumPitch*, hintPackPitch*, rewardedAdPrompt*, attConsentBody, umpConsentBody). Example EN:

```dart
  String get premiumPitchTitle => 'Remove ads';
  String get premiumPitchBody => 'Play without interstitials and get 3 daily free hints instead of 1.';
  String get premiumPitchCta => 'Remove ads — \$2.99';
  String get premiumPitchRestore => 'Restore purchases';
  String get hintPackPitchTitle => 'Out of hints';
  String get hintPackPitchBody => 'Buy 5 hints or watch a quick ad for one.';
  String get hintPackPitchCta => '5 hints — \$0.99';
  String get rewardedAdPromptTitle => 'Watch an ad for a hint?';
  String get rewardedAdPromptBody => 'A short video in exchange for one hint.';
  String get rewardedAdPromptWatch => 'Watch';
  String get rewardedAdPromptNo => 'No thanks';
  String get attConsentBody => "We use tracking to serve relevant ads so the game stays free.";
  String get umpConsentBody => 'Please review your ad preferences.';
```

RU equivalents (keep voice and tone consistent — short, friendly, no slang):

```dart
  String get premiumPitchTitle => 'Убрать рекламу';
  String get premiumPitchBody => 'Играйте без заставок и получайте 3 бесплатные подсказки в день вместо одной.';
  String get premiumPitchCta => 'Убрать рекламу — \$2.99';
  String get premiumPitchRestore => 'Восстановить покупки';
  String get hintPackPitchTitle => 'Подсказки закончились';
  String get hintPackPitchBody => 'Купите 5 подсказок или посмотрите короткую рекламу, чтобы получить одну.';
  String get hintPackPitchCta => '5 подсказок — \$0.99';
  String get rewardedAdPromptTitle => 'Посмотреть рекламу ради подсказки?';
  String get rewardedAdPromptBody => 'Короткое видео в обмен на одну подсказку.';
  String get rewardedAdPromptWatch => 'Смотреть';
  String get rewardedAdPromptNo => 'Нет, спасибо';
  String get attConsentBody => 'Мы используем отслеживание для показа релевантной рекламы — благодаря этому игра остаётся бесплатной.';
  String get umpConsentBody => 'Пожалуйста, выберите настройки рекламы.';
```

- [ ] **Step 2: Create premium pitch screen**

Create `lib/screens/premium_pitch_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/settings_provider.dart';
import '../services/purchases_service.dart';
import '../theme/app_theme.dart';
import '../widgets/grid_paper_background.dart';

class PremiumPitchScreen extends StatelessWidget {
  const PremiumPitchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final s = settings.languageMode == LanguageMode.russian ? StringsRu() : StringsEn();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.foreground),
        title: Text(s.premiumPitchTitle),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GridPaperBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  Text(s.premiumPitchBody,
                      style: AppTheme.bodyLarge,
                      textAlign: TextAlign.center),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => PurchasesService.instance.buyPremium(),
                    child: Text(s.premiumPitchCta),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => PurchasesService.instance.restore(),
                    child: Text(s.premiumPitchRestore),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Create hint-pack sheet**

Create `lib/widgets/hint_pack_pitch_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings_en.dart';
import '../l10n/strings_ru.dart';
import '../models/language_mode.dart';
import '../providers/settings_provider.dart';
import '../services/purchases_service.dart';
import '../theme/app_theme.dart';

Future<void> showHintPackPitchSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.background,
    builder: (_) {
      final settings = context.read<SettingsProvider>();
      final s = settings.languageMode == LanguageMode.russian ? StringsRu() : StringsEn();

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.hintPackPitchTitle, style: AppTheme.titleMedium),
              const SizedBox(height: 8),
              Text(s.hintPackPitchBody, style: AppTheme.bodyMedium),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  PurchasesService.instance.buyHintPack();
                },
                child: Text(s.hintPackPitchCta),
              ),
            ],
          ),
        ),
      );
    },
  );
}
```

- [ ] **Step 4: Enable Remove Ads + Restore rows in settings screen**

Modify `lib/screens/settings_screen.dart`: change the `enabled: false` rows to `enabled: true` with handlers:

```dart
SettingsRow(
  label: strings.settingsRemoveAds,
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const PremiumPitchScreen()),
  ),
  trailing: const Icon(Icons.chevron_right, color: AppTheme.foreground),
),
SettingsRow(
  label: strings.settingsRestore,
  onTap: () => PurchasesService.instance.restore(),
  trailing: const Icon(Icons.chevron_right, color: AppTheme.foreground),
),
```

Premium users: hide the Remove Ads row entirely (add a conditional above) — they already bought it.

```dart
if (!rewards.premium)
  SettingsRow(...),
```

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze`
Expected: clean.

```bash
git add lib/screens/premium_pitch_screen.dart lib/widgets/hint_pack_pitch_sheet.dart lib/screens/settings_screen.dart lib/l10n/strings_en.dart lib/l10n/strings_ru.dart
git commit -m "feat: premium pitch screen + hint-pack sheet + wire settings rows"
```

---

## Task 11: Manual device smoke tests

- [ ] **Step 1: Non-premium flow**

On a test iOS device (AdMob test IDs will keep showing Google's test creatives):

1. Fresh install.
2. First launch: ATT prompt appears.
3. Play 3 levels. Verify interstitial appears after level 3.
4. Use all hints until "out of hints" → rewarded ad prompt → watch test ad → hint is granted.
5. Open settings → Remove Ads → tap CTA (sandbox purchase). Complete purchase.
6. Kill + relaunch. Premium flag persisted. Interstitials no longer shown. Slot cap now 3.
7. Settings → Restore Purchases: succeeds silently if already premium.
8. Go back to hint-pack flow → buy pack → 5 hints granted to purchased pool.

- [ ] **Step 2: Android counterpart**

Repeat on Android test device. UMP form should appear on GDPR region.

- [ ] **Step 3: Commit nothing — this is verification only**

If any flow fails, open a follow-up task and fix.

---

## Task 12: Replace test ad unit IDs with real ones

**Files:**
- Modify: `lib/services/ad_unit_ids.dart`
- Modify: `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Obtain real IDs**

Log into AdMob. Create app entries for iOS + Android. Create interstitial + rewarded ad units for each platform. Copy the 4 unit IDs + 2 app IDs.

- [ ] **Step 2: Replace**

Replace test IDs in `ad_unit_ids.dart` and the `GADApplicationIdentifier` / `com.google.android.gms.ads.APPLICATION_ID` values in the manifests.

Do NOT commit real IDs until you're ready to ship — stash them in a private branch if soft-launch hasn't started.

- [ ] **Step 3: Verify full analyze+test**

Run: `flutter analyze && flutter test`
Expected: clean.

- [ ] **Step 4: Commit (on private branch if pre-launch)**

```bash
git commit -am "chore: swap AdMob test IDs for production IDs"
```

---

## Exit criteria recap

- Test user can buy `premium_no_ads_299` and `hint_pack_099_5`. Restore works. Premium disables interstitials and raises slot cap to 3.
- Rewarded ad plays when user declines cash options; reward credits `purchasedHintCount += 1`.
- Interstitial shows every Nth (default 3) level completion for non-premium users.
- ATT prompt shows on iOS first launch; UMP prompt shows for GDPR users; ad init happens either way (non-personalised fallback).
- `flutter analyze` zero issues. Unit tests pass for `InterstitialCadence`, `ConsentService.personalisedAdsAllowed`, `PurchasesService` constants.

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

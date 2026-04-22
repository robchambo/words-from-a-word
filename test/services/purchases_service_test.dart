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

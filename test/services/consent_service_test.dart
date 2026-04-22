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

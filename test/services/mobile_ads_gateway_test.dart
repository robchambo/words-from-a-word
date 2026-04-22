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

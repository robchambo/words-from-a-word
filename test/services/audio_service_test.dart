import 'package:flutter_test/flutter_test.dart';
import 'package:slova_iz_slova/services/audio_service.dart';

void main() {
  group('AudioService', () {
    final service = AudioService.instance;

    test('is a singleton', () {
      expect(AudioService.instance, same(service));
    });

    test('defaults to unmuted', () {
      // reset for test isolation
      service.setMuted(false);
      expect(service.isMuted, isFalse);
    });

    test('setMuted updates isMuted', () {
      service.setMuted(true);
      expect(service.isMuted, isTrue);
      service.setMuted(false);
      expect(service.isMuted, isFalse);
    });

    test('play* methods complete without throwing (no-op skeleton)', () async {
      await service.initialize();
      await service.playTap();
      await service.playSuccess();
      await service.playError();
      await service.playLevelComplete();
      await service.playHintReveal();
      await service.playFreeHintEarned();
      await service.playBonusRefill();
    });
  });
}

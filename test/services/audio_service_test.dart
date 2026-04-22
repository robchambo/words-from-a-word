import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:slova_iz_slova/services/audio_service.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _MockAudioCache extends Mock implements AudioCache {}

void main() {
  setUpAll(() {
    registerFallbackValue(AssetSource('placeholder.mp3'));
    registerFallbackValue(ReleaseMode.stop);
  });

  group('AudioService.initialize', () {
    test('preloads all 7 clips into AudioCache', () async {
      final cache = _MockAudioCache();
      when(() => cache.load(any())).thenAnswer((_) async => Uri());

      final service = AudioService.forTesting(
        players: [_MockAudioPlayer(), _MockAudioPlayer()],
        cache: cache,
      );
      await service.initialize();

      final calls = verify(() => cache.load(captureAny())).captured;
      expect(calls, containsAll(<String>[
        'audio/tap.mp3',
        'audio/success.mp3',
        'audio/error.mp3',
        'audio/level_complete.mp3',
        'audio/hint_reveal.mp3',
        'audio/free_hint_earned.mp3',
        'audio/bonus_refill.mp3',
      ]));
    });

    test('survives AudioCache.load throwing (placeholder MP3s)', () async {
      final cache = _MockAudioCache();
      when(() => cache.load(any())).thenThrow(Exception('bad mp3'));

      final service = AudioService.forTesting(
        players: [_MockAudioPlayer(), _MockAudioPlayer()],
        cache: cache,
      );

      // Must not throw despite every load failing.
      await service.initialize();
    });
  });

  group('AudioService muting', () {
    test('playTap does not call player.play when muted', () async {
      final player = _MockAudioPlayer();
      when(() => player.stop()).thenAnswer((_) async {});
      when(() => player.play(any())).thenAnswer((_) async {});
      final service = AudioService.forTesting(
        players: [player, player],
        cache: _MockAudioCache(),
      );

      service.setMuted(true);
      await service.playTap();

      verifyNever(() => player.play(any()));
    });

    test('playTap calls player.play when not muted', () async {
      final player = _MockAudioPlayer();
      when(() => player.stop()).thenAnswer((_) async {});
      when(() => player.play(any())).thenAnswer((_) async {});
      final service = AudioService.forTesting(
        players: [player, player],
        cache: _MockAudioCache(),
      );

      await service.playTap();

      verify(() => player.play(any())).called(1);
    });

    test('play-method failure does not propagate', () async {
      final player = _MockAudioPlayer();
      when(() => player.stop()).thenAnswer((_) async {});
      when(() => player.play(any())).thenThrow(Exception('no asset'));
      final service = AudioService.forTesting(
        players: [player, player],
        cache: _MockAudioCache(),
      );

      // Should complete without throwing.
      await service.playSuccess();
    });
  });
}

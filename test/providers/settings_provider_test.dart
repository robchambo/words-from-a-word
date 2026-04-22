import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/providers/settings_provider.dart';
import 'package:slova_iz_slova/services/audio_service.dart' as audio;

class _TrackingAudioService extends audio.AudioService {
  _TrackingAudioService()
      : super.forTesting(players: const [], cache: AudioCache(prefix: 'assets/'));

  final List<bool> muteCalls = [];

  @override
  void setMuted(bool muted) {
    muteCalls.add(muted);
    super.setMuted(muted);
  }
}

void main() {
  late _TrackingAudioService fakeAudio;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeAudio = _TrackingAudioService();
    audio.audioService = fakeAudio;
  });

  test('muted defaults to false', () async {
    final p = SettingsProvider();
    await p.load();

    expect(p.muted, isFalse);
    expect(fakeAudio.muteCalls, [false]);
    expect(fakeAudio.isMuted, isFalse);
  });

  test('setMuted persists, notifies, and syncs to AudioService', () async {
    final p = SettingsProvider();
    await p.load();

    var ticks = 0;
    p.addListener(() => ticks++);

    await p.setMuted(true);

    expect(p.muted, isTrue);
    expect(ticks, 1);
    expect(fakeAudio.muteCalls.last, isTrue);
    expect(fakeAudio.isMuted, isTrue);

    final p2 = SettingsProvider();
    await p2.load();
    expect(p2.muted, isTrue);
    expect(fakeAudio.muteCalls.last, isTrue);
  });
}

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Fire-and-forget sound-effects singleton. Real implementation using
/// `audioplayers` package. Preloads 7 clips at startup via `AudioCache` and
/// plays them via a 2-player pool (round-robin) so overlapping SFX don't
/// cut each other off. All load/play calls are wrapped in try/catch so the
/// app degrades gracefully when assets are missing or invalid (pre-launch
/// the clips are zero-byte placeholders).
class AudioService {
  AudioService._()
      : _players = _makePlayers(),
        _cache = AudioCache(prefix: 'assets/');

  @visibleForTesting
  AudioService.forTesting({
    required List<AudioPlayer> players,
    required AudioCache cache,
  })  : _players = players,
        _cache = cache;

  static final AudioService instance = AudioService._();

  final List<AudioPlayer> _players;
  final AudioCache _cache;
  int _next = 0;
  bool _muted = false;

  bool get isMuted => _muted;

  static const _clips = <String>[
    'audio/tap.mp3',
    'audio/success.mp3',
    'audio/error.mp3',
    'audio/level_complete.mp3',
    'audio/hint_reveal.mp3',
    'audio/free_hint_earned.mp3',
    'audio/bonus_refill.mp3',
  ];

  static List<AudioPlayer> _makePlayers() {
    final a = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    final b = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    return [a, b];
  }

  Future<void> initialize() async {
    for (final clip in _clips) {
      try {
        await _cache.load(clip);
      } catch (e, s) {
        debugPrint('AudioService: failed to preload $clip: $e\n$s');
      }
    }
  }

  void setMuted(bool muted) {
    _muted = muted;
  }

  Future<void> playTap() => _play('audio/tap.mp3');
  Future<void> playSuccess() => _play('audio/success.mp3');
  Future<void> playError() => _play('audio/error.mp3');
  Future<void> playLevelComplete() => _play('audio/level_complete.mp3');
  Future<void> playHintReveal() => _play('audio/hint_reveal.mp3');
  Future<void> playFreeHintEarned() => _play('audio/free_hint_earned.mp3');
  Future<void> playBonusRefill() => _play('audio/bonus_refill.mp3');

  Future<void> _play(String clip) async {
    if (_muted) return;
    final player = _players[_next];
    _next = (_next + 1) % _players.length;
    try {
      await player.stop();
      await player.play(AssetSource(clip));
    } catch (e, s) {
      debugPrint('AudioService: failed to play $clip: $e\n$s');
    }
  }
}

/// Mutable top-level binding for test injection. Production code reads and
/// writes through this variable rather than `AudioService.instance` directly
/// so tests can substitute a fake. Default points at the singleton.
AudioService audioService = AudioService.instance;

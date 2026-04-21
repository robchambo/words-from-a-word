import 'package:flutter/foundation.dart';

/// Fire-and-forget sound-effects singleton. Phase 1 skeleton: all play*
/// methods are no-ops so the wiring sites in later phases can be added
/// without waiting on audio assets. Phase 4 swaps the bodies for real
/// `audioplayers` calls.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  bool _muted = false;
  bool get isMuted => _muted;

  /// Preload clips. No-op in Phase 1.
  Future<void> initialize() async {
    debugPrint('[AudioService] initialize (skeleton)');
  }

  void setMuted(bool muted) {
    _muted = muted;
    debugPrint('[AudioService] setMuted($muted)');
  }

  Future<void> playTap() async {}
  Future<void> playSuccess() async {}
  Future<void> playError() async {}
  Future<void> playLevelComplete() async {}
  Future<void> playHintReveal() async {}
  Future<void> playFreeHintEarned() async {}
  Future<void> playBonusRefill() async {}
}

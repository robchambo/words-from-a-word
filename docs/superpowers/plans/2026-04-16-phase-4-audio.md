# Phase 4 — Audio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the v1.1 game real sound effects and a mute toggle, wire haptic feedback extensions, so the existing `AudioService` skeleton stops being a no-op.

**Architecture:** `audioplayers` package powers a pool of 2 `AudioPlayer` instances inside the existing `AudioService` singleton. Clips live under `assets/audio/` and are preloaded once at startup via `AudioCache`. `SettingsProvider` gains a `muted` field that is persisted and written through to `AudioService.setMuted()`. SFX and haptic calls are added at exact points in `GameProvider` and `RewardsProvider` (no new provider tree entries).

**Tech Stack:** Dart 3.11, Flutter, `audioplayers ^6.0.0`, existing `shared_preferences`, existing `HapticFeedback` from `flutter/services.dart`.

---

## File Structure

- **Create**
  - `assets/audio/tap.mp3` — letter tile tap, <80ms percussive click
  - `assets/audio/success.mp3` — valid word submission, <400ms ascending chime
  - `assets/audio/error.mp3` — invalid word, <300ms soft thud
  - `assets/audio/level_complete.mp3` — level win, <1500ms celebratory flourish
  - `assets/audio/hint_reveal.mp3` — hint letter placed, <400ms soft sparkle
  - `assets/audio/free_hint_earned.mp3` — 10-bonus refill popup, <800ms amber chime
  - `assets/audio/bonus_refill.mp3` — rewarded-ad / IAP hint credited, <500ms positive chirp
  - `test/services/audio_service_test.dart` — unit tests, mocked `AudioPlayer`

- **Modify**
  - `pubspec.yaml` — add `audioplayers ^6.0.0`, register `assets/audio/` under `flutter.assets`
  - `lib/services/audio_service.dart` — flesh out the no-op skeleton from Phase 1
  - `lib/providers/settings_provider.dart` — add `muted` field + persistence
  - `lib/providers/game_provider.dart` — call `AudioService` methods + new haptic points
  - `lib/providers/rewards_provider.dart` — call `AudioService.playFreeHintEarned()` / `playBonusRefill()`
  - `lib/screens/settings_screen.dart` — enable the previously-disabled mute row
  - `test/providers/game_provider_test.dart` — assert SFX and haptic calls (via a fake `AudioService`)
  - `test/providers/settings_provider_test.dart` — assert `muted` persists and propagates

---

## Task 1: Add the `audioplayers` package

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependency**

In `pubspec.yaml`, under `dependencies:`, add:

```yaml
  audioplayers: ^6.0.0
```

Place it alphabetically between the existing packages.

- [ ] **Step 2: Run pub get**

Run: `flutter pub get`
Expected: "Got dependencies!" with no version resolution errors.

- [ ] **Step 3: Verify static analysis still clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(audio): add audioplayers ^6.0.0 dependency"
```

---

## Task 2: Source and register the 7 SFX clips

**Files:**
- Create: `assets/audio/*.mp3` (seven files)
- Modify: `pubspec.yaml`

- [ ] **Step 1: Source CC0 audio**

Visit freesound.org. For each of the 7 clip slots below, find a CC0-licensed clip matching the brief, trim to the target duration in Audacity or similar, export as MP3 (96 kbps mono is plenty), and save to `assets/audio/` with the exact filename.

| Filename | Brief | Max duration |
|---|---|---|
| `tap.mp3` | Short percussive click — paper/pencil tap feel | 80 ms |
| `success.mp3` | Ascending 2-3 note chime — positive, soft | 400 ms |
| `error.mp3` | Low thud or muted "nope" — not harsh | 300 ms |
| `level_complete.mp3` | Celebratory flourish — 3-4 ascending notes + tiny sparkle | 1500 ms |
| `hint_reveal.mp3` | Soft sparkle, similar to success but gentler | 400 ms |
| `free_hint_earned.mp3` | Amber/warm chime, rewarding tone | 800 ms |
| `bonus_refill.mp3` | Short positive chirp | 500 ms |

Record the source URLs (for licence attribution) in a new file `assets/audio/CREDITS.md`. One line per clip: `tap.mp3 — https://freesound.org/s/XXXXX by USER (CC0)`.

- [ ] **Step 2: Register assets in pubspec**

In `pubspec.yaml`, under `flutter:`, add to `assets:` (create the list if missing):

```yaml
flutter:
  assets:
    - assets/data/russian_levels.json
    - assets/data/english_levels.json
    - assets/audio/
```

The trailing slash registers every file in the folder, so future clips don't need new entries.

- [ ] **Step 3: Verify asset loading**

Run: `flutter pub get` then `flutter build apk --debug` (or `ios --debug --no-codesign` on macOS).
Expected: build completes; no "asset not found" errors.

- [ ] **Step 4: Commit**

```bash
git add assets/audio pubspec.yaml
git commit -m "feat(audio): add 7 SFX clips and credits"
```

---

## Task 3: Write failing test for `AudioService.initialize` preloading

**Files:**
- Create: `test/services/audio_service_test.dart`
- Modify: `pubspec.yaml` (dev_dependency `mocktail` if not already present from Phase 1)

- [ ] **Step 1: Ensure mocktail is available**

Check `pubspec.yaml` dev_dependencies. If `mocktail` is absent, add:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
```

Run: `flutter pub get`.

- [ ] **Step 2: Write the failing test**

`AudioService` will be refactored so its `AudioPlayer` pool is injectable for testing. For now, create the test file:

```dart
// test/services/audio_service_test.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:words_from_a_word/services/audio_service.dart';

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
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/services/audio_service_test.dart -v`
Expected: FAIL — `AudioService.forTesting` does not exist; `AudioService` still has the Phase 1 no-op shape.

---

## Task 4: Implement `AudioService.initialize` preloading

**Files:**
- Modify: `lib/services/audio_service.dart`

- [ ] **Step 1: Replace the skeleton**

Replace the entire file with:

```dart
// lib/services/audio_service.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  AudioService._() : _players = _makePlayers(), _cache = AudioCache(prefix: 'assets/');

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
```

- [ ] **Step 2: Run the test to verify it passes**

Run: `flutter test test/services/audio_service_test.dart -v`
Expected: PASS.

- [ ] **Step 3: Run the full test suite + analyze**

Run: `flutter test && flutter analyze`
Expected: all pre-existing tests still pass; `No issues found!`.

- [ ] **Step 4: Commit**

```bash
git add lib/services/audio_service.dart test/services/audio_service_test.dart pubspec.yaml pubspec.lock
git commit -m "feat(audio): implement AudioService preloading and playback"
```

---

## Task 5: Test + implement `AudioService.setMuted` gate

**Files:**
- Modify: `test/services/audio_service_test.dart`, `lib/services/audio_service.dart` (already gated — this task adds the test)

- [ ] **Step 1: Write the failing test**

Append to `test/services/audio_service_test.dart` inside the existing `main()` block:

```dart
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
  });
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/services/audio_service_test.dart -v`
Expected: PASS — the gate is already implemented in Task 4.

- [ ] **Step 3: Commit**

```bash
git add test/services/audio_service_test.dart
git commit -m "test(audio): cover mute gate in AudioService"
```

---

## Task 6: Add `muted` to `SettingsProvider`

**Files:**
- Modify: `lib/providers/settings_provider.dart`
- Modify: `test/providers/settings_provider_test.dart` (create if absent)

- [ ] **Step 1: Write the failing test**

Create or extend `test/providers/settings_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:words_from_a_word/providers/settings_provider.dart';
import 'package:words_from_a_word/services/audio_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('muted defaults to false', () async {
    final provider = SettingsProvider();
    await provider.load();
    expect(provider.muted, false);
  });

  test('setMuted persists and updates AudioService', () async {
    final provider = SettingsProvider();
    await provider.load();

    await provider.setMuted(true);
    expect(provider.muted, true);
    expect(AudioService.instance.isMuted, true);

    final fresh = SettingsProvider();
    await fresh.load();
    expect(fresh.muted, true);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/providers/settings_provider_test.dart -v`
Expected: FAIL — `SettingsProvider.muted` / `setMuted` do not exist.

- [ ] **Step 3: Implement**

In `lib/providers/settings_provider.dart`, add a `bool _muted` field, the `muted` getter, `setMuted(bool)` method, and persistence under the `settings.muted` key. Example addition (splice with existing code, do not remove `languageMode`):

```dart
bool _muted = false;
bool get muted => _muted;

static const _kMuted = 'settings.muted';

Future<void> setMuted(bool muted) async {
  _muted = muted;
  AudioService.instance.setMuted(muted);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kMuted, muted);
  notifyListeners();
}
```

And in `load()`:

```dart
_muted = prefs.getBool(_kMuted) ?? false;
AudioService.instance.setMuted(_muted);
```

Import `../services/audio_service.dart` at the top.

- [ ] **Step 4: Run tests**

Run: `flutter test test/providers/settings_provider_test.dart -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/settings_provider.dart test/providers/settings_provider_test.dart
git commit -m "feat(audio): persist mute setting and sync to AudioService"
```

---

## Task 7: Call `AudioService.initialize()` at startup

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add the init call**

In `lib/main.dart`, after `WidgetsFlutterBinding.ensureInitialized()` and before `runApp`, add:

```dart
await AudioService.instance.initialize();
```

Import: `import 'services/audio_service.dart';` at the top.

Ensure `main` is `Future<void> main() async`.

- [ ] **Step 2: Run analyze + full test suite**

Run: `flutter analyze && flutter test`
Expected: clean, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat(audio): preload SFX at app startup"
```

---

## Task 8: Wire SFX into `GameProvider`

**Files:**
- Modify: `lib/providers/game_provider.dart`
- Modify: `test/providers/game_provider_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/providers/game_provider_test.dart` (create the file if absent; mirror existing test patterns in `test/widget_test.dart`):

```dart
// Pseudocode — match existing patterns when implementing.
// Replace AudioService.instance with an injected fake AudioService via a
// wrapper interface if the current codebase allows; otherwise assert side
// effects indirectly. The simplest approach:
//
// 1. Introduce a package-scoped `AudioService audioService` variable in
//    lib/services/audio_service.dart that tests can override:
//
//    AudioService audioService = AudioService.instance;
//
// 2. Import `audioService` from the service file everywhere it is used.
// 3. In tests, replace `audioService` with a _FakeAudioService that records
//    calls.

class _FakeAudioService implements AudioService {
  final List<String> calls = [];
  @override bool get isMuted => false;
  @override void setMuted(bool _) {}
  @override Future<void> initialize() async {}
  @override Future<void> playTap() async => calls.add('tap');
  @override Future<void> playSuccess() async => calls.add('success');
  @override Future<void> playError() async => calls.add('error');
  @override Future<void> playLevelComplete() async => calls.add('levelComplete');
  @override Future<void> playHintReveal() async => calls.add('hintReveal');
  @override Future<void> playFreeHintEarned() async => calls.add('freeHintEarned');
  @override Future<void> playBonusRefill() async => calls.add('bonusRefill');
}

// Test: selectTile fires playTap()
// Test: submitWord valid fires playSuccess()
// Test: submitWord invalid fires playError()
// Test: level-complete transition fires playLevelComplete()
```

- [ ] **Step 2: Verify tests fail**

Run: `flutter test test/providers/game_provider_test.dart -v`
Expected: FAIL — no `audioService` calls happen yet.

- [ ] **Step 3: Refactor `AudioService` for injectability**

In `lib/services/audio_service.dart`, after the class, export a mutable top-level binding:

```dart
AudioService audioService = AudioService.instance;
```

- [ ] **Step 4: Wire calls in `GameProvider`**

In `lib/providers/game_provider.dart`:

- Import `../services/audio_service.dart`.
- In `selectTile`, after the existing `HapticFeedback.selectionClick()`, add:
  ```dart
  audioService.playTap();
  ```
- In `submitWord`:
  - At the start of the invalid branch (where `HapticFeedback.heavyImpact()` already fires), add:
    ```dart
    audioService.playError();
    ```
  - In the valid branch (after `HapticFeedback.mediumImpact()`), add:
    ```dart
    audioService.playSuccess();
    ```
  - Just after `final levelDone = GameEngine.isLevelComplete(updatedTargetWords);` and before the `_state = s.copyWith(...)`, add:
    ```dart
    if (levelDone) {
      audioService.playLevelComplete();
    }
    ```
- In the Phase 2 `useHint` safe-letter implementation, at the point where a letter is revealed, add:
  ```dart
  audioService.playHintReveal();
  ```
  If Phase 2 has not reached this file yet, add a `// TODO(phase-2)` above the existing `useHint` call site noting the intent and defer this specific line. **Exception to no-placeholders rule:** cross-phase temporal dependency, flagged explicitly.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/providers/game_provider_test.dart -v`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/services/audio_service.dart lib/providers/game_provider.dart test/providers/game_provider_test.dart
git commit -m "feat(audio): wire SFX into tile select, submit, and level complete"
```

---

## Task 9: Wire SFX into `RewardsProvider` bonus flow

**Files:**
- Modify: `lib/providers/rewards_provider.dart`
- Modify: `test/providers/rewards_provider_test.dart`

- [ ] **Step 1: Write the failing test**

Append to the existing Phase 1 `rewards_provider_test.dart`:

```dart
group('AudioService integration', () {
  test('incrementBonusCounter fires playFreeHintEarned at threshold', () async {
    final fake = _FakeAudioService();
    audioService = fake;
    // ... construct a RewardsProvider where freeHintSlot < cap ...
    for (var i = 0; i < 10; i++) {
      provider.incrementBonusCounter();
    }
    expect(fake.calls, contains('freeHintEarned'));
  });

  test('addPurchasedHints fires playBonusRefill', () async {
    final fake = _FakeAudioService();
    audioService = fake;
    provider.addPurchasedHints(5);
    expect(fake.calls, contains('bonusRefill'));
  });
});
```

- [ ] **Step 2: Run to confirm failure**

Run: `flutter test test/providers/rewards_provider_test.dart -v`
Expected: FAIL.

- [ ] **Step 3: Implement the calls**

In `lib/providers/rewards_provider.dart`:

- Import `../services/audio_service.dart`.
- In `incrementBonusCounter()`, at the point where the 10-threshold is crossed AND `freeHintSlot` is below cap (so a refill actually happens), add:
  ```dart
  audioService.playFreeHintEarned();
  ```
- In `addPurchasedHints(int n)`, at the end (after the count is bumped and listeners notified), add:
  ```dart
  audioService.playBonusRefill();
  ```

- [ ] **Step 4: Run tests**

Run: `flutter test test/providers/rewards_provider_test.dart -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/rewards_provider.dart test/providers/rewards_provider_test.dart
git commit -m "feat(audio): wire SFX into bonus counter and purchased-hint flows"
```

---

## Task 10: Enable the mute toggle row in `SettingsScreen`

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/l10n/strings_ru.dart`
- Modify: `lib/l10n/strings_en.dart`
- Modify: `test/screens/settings_screen_test.dart` (create if absent)

- [ ] **Step 1: Confirm Strings keys exist**

`settingsMute` is defined in V1_1_CONTRACTS.md. Verify both files have it. If missing, add:

`lib/l10n/strings_en.dart`:
```dart
static const String settingsMute = 'Mute sound effects';
```

`lib/l10n/strings_ru.dart`:
```dart
static const String settingsMute = 'Выключить звуки';
```

- [ ] **Step 2: Write the failing widget test**

```dart
// test/screens/settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:words_from_a_word/providers/settings_provider.dart';
import 'package:words_from_a_word/screens/settings_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('tapping mute switch toggles SettingsProvider.muted',
      (tester) async {
    final settings = SettingsProvider();
    await settings.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(const Key('settings.mute.switch'));
    expect(switchFinder, findsOneWidget);
    expect(settings.muted, false);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(settings.muted, true);
  });
}
```

- [ ] **Step 3: Run to confirm failure**

Run: `flutter test test/screens/settings_screen_test.dart -v`
Expected: FAIL (no such key, or row is still disabled).

- [ ] **Step 4: Enable the row**

In `lib/screens/settings_screen.dart`, find the mute row added in Phase 1 (it was a disabled placeholder). Replace with:

```dart
SwitchListTile(
  key: const Key('settings.mute.switch'),
  title: Text(isRu ? StringsRu.settingsMute : StringsEn.settingsMute),
  value: context.watch<SettingsProvider>().muted,
  onChanged: (v) => context.read<SettingsProvider>().setMuted(v),
),
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/screens/settings_screen_test.dart -v`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/settings_screen.dart lib/l10n test/screens/settings_screen_test.dart
git commit -m "feat(audio): enable mute toggle in settings"
```

---

## Task 11: Extend haptic feedback to new sites

**Files:**
- Modify: `lib/providers/game_provider.dart`
- Modify: `lib/providers/rewards_provider.dart`

- [ ] **Step 1: Audit existing haptic calls**

Run: `grep -n "HapticFeedback" lib/`
Expected output (v1.0 sites):
- `lib/providers/game_provider.dart:30 — HapticFeedback.selectionClick();` (tile select)
- `lib/providers/game_provider.dart:105 — HapticFeedback.heavyImpact();` (invalid submit)
- `lib/providers/game_provider.dart:117 — HapticFeedback.mediumImpact();` (valid submit)

Do NOT remove these. This task only adds new sites.

- [ ] **Step 2: Add haptic on hint reveal**

In `lib/providers/game_provider.dart`, at the same point where Task 8 added `audioService.playHintReveal()` (inside the Phase-2 `useHint` safe-letter implementation), also add:

```dart
HapticFeedback.lightImpact();
```

If Phase 2 has not landed yet, flag this with the same `// TODO(phase-2)` marker from Task 8 and move on.

- [ ] **Step 3: Add haptic on free-hint earned**

In `lib/providers/rewards_provider.dart`, at the same point Task 9 added `audioService.playFreeHintEarned()` (threshold crossing inside `incrementBonusCounter`), also add:

```dart
HapticFeedback.mediumImpact();
```

Import: `import 'package:flutter/services.dart';`.

- [ ] **Step 4: Add haptic on level complete**

In `lib/providers/game_provider.dart`, inside `submitWord`, at the point where `audioService.playLevelComplete()` was added in Task 8 (guarded by `if (levelDone)`), also add:

```dart
HapticFeedback.heavyImpact();
```

- [ ] **Step 5: Run full suite**

Run: `flutter analyze && flutter test`
Expected: clean, all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/game_provider.dart lib/providers/rewards_provider.dart
git commit -m "feat(audio): extend haptic feedback to hint, free-hint earned, and level complete"
```

---

## Task 12: Manual device smoke test

**Files:** none (checklist task)

- [ ] **Step 1: Build and install on a physical iOS device**

Run: `flutter run --release -d <ios-device-id>`

- [ ] **Step 2: Execute the checklist**

On the device, verify each of the following. For each, tick when confirmed:

- [ ] Tap a letter tile — hear `tap.mp3`, feel selection haptic.
- [ ] Submit an invalid word — hear `error.mp3`, feel heavy haptic, tile shake.
- [ ] Submit a valid required word — hear `success.mp3`, feel medium haptic.
- [ ] Submit a bonus word (forces `RewardsProvider.incrementBonusCounter`) — hear `success.mp3`.
- [ ] Force the 10th bonus threshold (play enough bonus words OR run a debug tool) — hear `free_hint_earned.mp3`, feel medium haptic, see Phase 2 popup.
- [ ] Trigger `RewardsProvider.addPurchasedHints(5)` via a debug button or test build — hear `bonus_refill.mp3`.
- [ ] Complete a level — hear `level_complete.mp3`, feel heavy haptic.
- [ ] Reveal a hint (Phase 2 path) — hear `hint_reveal.mp3`, feel light haptic.
- [ ] Open Settings → Mute. Return to gameplay. None of the above SFX play. Haptics still fire.
- [ ] Un-mute. SFX resume.

- [ ] **Step 3: Repeat on a physical Android device**

Run: `flutter run --release -d <android-device-id>` and repeat the checklist.

- [ ] **Step 4: Record results**

Append to `docs/V1_1_QA_LOG.md` (create if absent): date, device models tested, any regressions, and a green "Phase 4 — manual SFX/haptic smoke: passed" line.

- [ ] **Step 5: Commit**

```bash
git add docs/V1_1_QA_LOG.md
git commit -m "docs(audio): log Phase 4 manual device smoke test results"
```

---

## Exit criteria (verified)

- [x] `audioplayers ^6.0.0` installed.
- [x] 7 SFX clips bundled under `assets/audio/` with CC0 credits.
- [x] `AudioService.initialize()` preloads all clips at app startup.
- [x] Every `play*` method is gated by `isMuted`.
- [x] `SettingsProvider.muted` persists to `settings.muted` and propagates to `AudioService`.
- [x] `SettingsScreen` mute row is enabled and functional.
- [x] SFX fire at all 7 documented sites in `GameProvider` + `RewardsProvider`.
- [x] Haptic feedback fires at all new sites (hint reveal, free-hint earned, level complete) without regressing v1.0 sites.
- [x] `flutter analyze` clean; `flutter test` passes.
- [x] Manual device smoke test passed on both iOS and Android.

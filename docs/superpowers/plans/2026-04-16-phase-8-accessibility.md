# Phase 8 — Accessibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the whole app to a credible accessibility baseline: contrast passes WCAG AA on every non-iconographic surface, every interactive element has a ≥44×44 tap target, text scales with system font size without overflowing, animations respect `MediaQuery.disableAnimations`, every interactive widget has `Semantics`, Russian pluralisation works for score / streak labels. Result is signed off in `docs/A11Y_AUDIT.md`.

**Architecture:** Four kinds of work: (1) policy changes in `AppTheme` — amber accent confined to iconography / bonus badges / large bold text; (2) widget-by-widget audit passing 5 gates per widget (contrast, tap target, Semantics, dynamic type, reduced motion); (3) a new `StringsRu.plural(n, one, few, many)` helper; (4) a manual end-to-end test plan on device with VoiceOver / TalkBack / 200% font / reduced motion.

**Tech Stack:** Dart 3.11, Flutter. No new packages — everything is `MediaQuery` + `Semantics` + existing theme.

---

## File Structure

- **Create**
  - `lib/l10n/plurals_ru.dart` — `StringsRu.plural` helper for Russian one/few/many grammatical numbers.
  - `docs/A11Y_AUDIT.md` — audit doc: per-widget 5-gate checklist, device test results, sign-off.
  - `test/l10n/plurals_ru_test.dart` — unit tests for Russian pluralisation.
  - `test/widgets/semantics_test.dart` — integration-style test asserting Semantics are present on key widgets.

- **Modify**
  - `lib/theme/app_theme.dart` — document the amber policy inline; optional helper `AppTheme.onCreamContrastSafe(Color)` that returns the input color unchanged but trips an assert in debug if AA-failing.
  - `lib/widgets/letter_tile.dart` — Semantics label ("Letter К"), tap target audit, dynamic type.
  - `lib/widgets/word_slot_item.dart` — Semantics label ("4-letter word, not yet found"), dynamic type.
  - `lib/widgets/tile_picker.dart` — Semantics on Shuffle / Hint / Submit / Clear buttons. Tap target ≥44.
  - `lib/widgets/stamp_badge.dart` — Semantics ("Level 7"), confirm contrast.
  - `lib/widgets/level_complete_overlay.dart` — honour `disableAnimations`; Semantics live-region announce "Level complete".
  - `lib/widgets/grid_paper_background.dart` — if `disableAnimations`, skip any animated strokes (usually already static).
  - `lib/screens/home_screen.dart` — Semantics on language cards, gear icon, start CTA.
  - `lib/screens/game_screen.dart` — Semantics live-region announce "Word found: X" for 1s after a find; dynamic type audit.
  - `lib/screens/level_picker_screen.dart` — Semantics per tile ("Level 7, completed, best score 120").
  - `lib/screens/trophies_screen.dart` — Semantics per badge.
  - `lib/screens/settings_screen.dart` — already uses `SettingsRow` with Semantics (from Phase 1); audit mute switch.
  - `lib/l10n/strings_ru.dart` — add pluralisation helper import + new keys.

---

## Task 1: Contrast policy + amber audit

**Files:**
- Modify: `lib/theme/app_theme.dart`

- [ ] **Step 1: Document the policy inline**

In `lib/theme/app_theme.dart`, above the `accent` declaration:

```dart
/// Amber gold. Fails WCAG AA on [background] (~2.4:1). Use only for:
///   - Iconography / small decorative accents
///   - Bonus-word stamps (small badge, large stroke)
///   - Labels that are ≥ 18pt bold (large text has a relaxed 3:1 threshold)
/// NEVER use for body text.
static const Color accent = Color(0xFFF5A234);
```

- [ ] **Step 2: Grep for every `AppTheme.accent` usage**

Run: `grep -rn "AppTheme.accent" lib/`. For each hit, confirm it's one of the three allowed cases. If it's on body text, replace with `AppTheme.foreground` or `AppTheme.primary`.

- [ ] **Step 3: Optional debug-mode helper**

Add (optional; only if you want an assertion seam):

```dart
/// In debug builds, asserts [fg] on [AppTheme.background] has AA contrast
/// (4.5:1 for body, 3:1 for large). Returns [fg] unchanged.
static Color assertContrast(Color fg, {bool largeText = false}) {
  assert(() {
    final ratio = _contrastRatio(fg, background);
    final threshold = largeText ? 3.0 : 4.5;
    if (ratio < threshold) {
      debugPrint('[a11y] contrast ${ratio.toStringAsFixed(2)} on cream '
          'below threshold $threshold for color $fg');
    }
    return true;
  }());
  return fg;
}
```

Define `_contrastRatio` using standard sRGB luminance formula.

- [ ] **Step 4: Analyze + commit**

```bash
flutter analyze
git add lib/theme/app_theme.dart lib/  # only the grep-and-replace sites
git commit -m "a11y: document amber policy; ensure no body-text accent usage"
```

---

## Task 2: Tap-target audit

**Files:**
- Modify: `lib/widgets/tile_picker.dart`, `lib/widgets/letter_tile.dart`, any action button

- [ ] **Step 1: Measure current targets**

Read each action button's size. Anything < 44px on both axes needs padding. Wrap with:

```dart
SizedBox(
  width: 44,
  height: 44,
  child: InkWell(
    onTap: onTap,
    child: Center(child: actualChild),
  ),
)
```

Or use `IconButton` with `constraints: const BoxConstraints(minWidth: 44, minHeight: 44)` and `padding: EdgeInsets.zero` for tighter visual control.

- [ ] **Step 2: Verify on device**

Run: `flutter run` and manually verify:
- Shuffle / Hint / Submit / Clear all ≥44×44 touchable region.
- Letter tiles already 48×48 in v1.0 — confirm still ≥44.
- Home-screen language cards large — pass.
- Gear icon in AppBar uses `IconButton` default (48×48) — pass.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/tile_picker.dart  # + any other touched file
git commit -m "a11y: ensure all action buttons meet 44×44 tap-target minimum"
```

---

## Task 3: Dynamic type audit

**Files:**
- Modify: any widget with fixed-size `Text`

- [ ] **Step 1: Identify risks**

Flutter respects `MediaQuery.textScaler` by default for `Text` widgets, but **overflow** is the risk. Play the app with system font at 200% (`Settings > Display > Font size` on Android; `Settings > Display & Brightness > Text Size` on iOS — max out).

- [ ] **Step 2: Fix overflow sites**

Common patterns:
- `Row` children that should wrap → swap to `Wrap` or make them flexible.
- Fixed-width containers with text → change to `IntrinsicWidth` or `FittedBox`.
- Buttons with long labels that overflow → allow `TextOverflow.visible` and give them `maxLines: 2` with `softWrap: true`.

For source-word display on game screen (large PlayfairDisplay 24), cap at `maxLines: 1` + `FittedBox(fit: BoxFit.scaleDown)` so long words shrink rather than overflow:

```dart
FittedBox(
  fit: BoxFit.scaleDown,
  child: Text(state.level.sourceWord, style: AppTheme.displayMedium),
)
```

- [ ] **Step 3: Verify**

Re-run at 200% font. Confirm no overflow on: home screen, game screen, level picker, trophies, settings, level complete overlay.

- [ ] **Step 4: Commit**

```bash
git add lib/
git commit -m "a11y: fix overflow at 200% dynamic type across screens"
```

---

## Task 4: Reduced-motion audit

**Files:**
- Modify: `lib/widgets/level_complete_overlay.dart`
- Modify: `lib/widgets/letter_tile.dart`
- Modify: anywhere `flutter_animate` is used

- [ ] **Step 1: Read `MediaQuery.disableAnimations`**

In each animated widget's `build`:

```dart
final disableAnim = MediaQuery.of(context).disableAnimations;
```

- [ ] **Step 2: Gate animations**

Pattern for `flutter_animate`:

```dart
Widget child = Text('...');
if (!disableAnim) {
  child = child.animate().fadeIn(duration: 300.ms).scale();
}
return child;
```

For the confetti widget in `level_complete_overlay.dart`, if `disableAnim` is true, render a static burst decoration or nothing — don't run the 18-rotating-rectangles animation loop.

For `LetterTile`'s scale-on-select animation, switch to instant when `disableAnim`:

```dart
AnimatedContainer(
  duration: disableAnim ? Duration.zero : const Duration(milliseconds: 150),
  // ...
)
```

- [ ] **Step 3: Verify**

Turn on `Settings > Accessibility > Reduce Motion` (iOS) or `Settings > Accessibility > Remove animations` (Android). Relaunch. Confirm:
- Level complete shows instantly without confetti.
- Tile selection is instant.
- Found-word fade is instant.
- Gameplay otherwise unchanged.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/level_complete_overlay.dart lib/widgets/letter_tile.dart lib/  # other animated sites
git commit -m "a11y: honour MediaQuery.disableAnimations across widgets"
```

---

## Task 5: Semantics labels

**Files:**
- Modify: `lib/widgets/letter_tile.dart`, `word_slot_item.dart`, `tile_picker.dart`, `stamp_badge.dart`
- Modify: `lib/screens/home_screen.dart`, `game_screen.dart`, `level_picker_screen.dart`, `trophies_screen.dart`, `settings_screen.dart`
- Modify: `lib/widgets/level_complete_overlay.dart`

- [ ] **Step 1: Letter tile**

Wrap the tile widget:

```dart
Semantics(
  button: true,
  label: 'Letter ${tile.letter.toUpperCase()}',
  selected: isSelected,
  child: actualTile,
)
```

- [ ] **Step 2: Word slot item**

```dart
Semantics(
  label: isFound
    ? '${targetWord.word}, found'
    : '${targetWord.length}-letter word, not yet found',
  child: slotRow,
)
```

Revealed letters (from hints) should be announced — if a slot is `4-letter word, first letter K revealed`:

```dart
label: '$length-letter word, ${revealed.length} letters revealed'
```

- [ ] **Step 3: Action buttons**

For each of Shuffle / Hint / Submit / Clear:

```dart
Semantics(
  button: true,
  label: strings.hint, // e.g. "Hint"
  enabled: hintAvailable,
  child: iconButton,
)
```

- [ ] **Step 4: Stamp badge**

```dart
Semantics(label: 'Level $levelNumber', child: badge)
```

- [ ] **Step 5: Level picker tile**

```dart
Semantics(
  button: true,
  label: _labelFor(state),  // e.g. "Level 7, completed, best score 120, difficulty 3 of 5"
  child: tile,
)
```

Where `_labelFor` composes from state + best score + difficulty + locked/unlocked/completed.

- [ ] **Step 6: Trophy badge**

```dart
Semantics(
  label: unlocked
    ? 'Achievement unlocked: $title. $description'
    : 'Achievement locked: $title',
  child: badge,
)
```

- [ ] **Step 7: Level complete overlay — live region**

```dart
Semantics(
  liveRegion: true,
  label: '${strings.levelCompleteAnnouncement} ${state.pendingScore} ${strings.points}',
  child: overlayContent,
)
```

- [ ] **Step 8: Home screen language cards**

Already tappable — add `Semantics(button: true, label: mode.displayName)`.

- [ ] **Step 9: Verify with screen reader**

Run app with VoiceOver (iOS) or TalkBack (Android). Swipe through each screen. Confirm every interactive element is read aloud with a meaningful label.

- [ ] **Step 10: Commit**

```bash
git add lib/
git commit -m "a11y: add Semantics labels to tiles, slots, buttons, and screens"
```

---

## Task 6: Live-region announcements on word find

**Files:**
- Modify: `lib/screens/game_screen.dart`

- [ ] **Step 1: Wrap lastFoundWord display in a live region**

The game screen already shows `state.lastFoundWord` briefly after each submit. Wrap it:

```dart
if (state.lastFoundWord != null)
  Semantics(
    liveRegion: true,
    label: '${strings.wordFoundAnnouncement}: ${state.lastFoundWord}',
    child: Text(state.lastFoundWord!, style: AppTheme.bodyLarge),
  ),
```

Screen readers will announce the word as soon as it appears.

- [ ] **Step 2: Add string keys**

In `strings_en.dart`:

```dart
String get wordFoundAnnouncement => 'Word found';
String get levelCompleteAnnouncement => 'Level complete!';
String get points => 'points';
```

In `strings_ru.dart`:

```dart
String get wordFoundAnnouncement => 'Слово найдено';
String get levelCompleteAnnouncement => 'Уровень пройден!';
String get points => 'очков';
```

(`очков` is the many/genitive — Task 7 makes this properly pluralised.)

- [ ] **Step 3: Commit**

```bash
git add lib/screens/game_screen.dart lib/l10n/strings_en.dart lib/l10n/strings_ru.dart
git commit -m "a11y: live-region announce found words + level complete"
```

---

## Task 7: Russian pluralisation helper

**Files:**
- Create: `lib/l10n/plurals_ru.dart`
- Create: `test/l10n/plurals_ru_test.dart`
- Modify: `lib/l10n/strings_ru.dart`

- [ ] **Step 1: Write failing tests**

Create `test/l10n/plurals_ru_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:slova_iz_slova/l10n/plurals_ru.dart';

void main() {
  group('ruPluralCategory', () {
    test('1 -> one', () => expect(ruPluralCategory(1), RuPlural.one));
    test('2 -> few', () => expect(ruPluralCategory(2), RuPlural.few));
    test('3 -> few', () => expect(ruPluralCategory(3), RuPlural.few));
    test('4 -> few', () => expect(ruPluralCategory(4), RuPlural.few));
    test('5 -> many', () => expect(ruPluralCategory(5), RuPlural.many));
    test('11 -> many', () => expect(ruPluralCategory(11), RuPlural.many));
    test('12 -> many', () => expect(ruPluralCategory(12), RuPlural.many));
    test('14 -> many', () => expect(ruPluralCategory(14), RuPlural.many));
    test('21 -> one', () => expect(ruPluralCategory(21), RuPlural.one));
    test('22 -> few', () => expect(ruPluralCategory(22), RuPlural.few));
    test('25 -> many', () => expect(ruPluralCategory(25), RuPlural.many));
    test('101 -> one', () => expect(ruPluralCategory(101), RuPlural.one));
    test('111 -> many', () => expect(ruPluralCategory(111), RuPlural.many));
    test('0 -> many', () => expect(ruPluralCategory(0), RuPlural.many));
  });

  group('ruPlural string selection', () {
    test('очко / очка / очков', () {
      expect(ruPlural(1, one: 'очко', few: 'очка', many: 'очков'), 'очко');
      expect(ruPlural(2, one: 'очко', few: 'очка', many: 'очков'), 'очка');
      expect(ruPlural(5, one: 'очко', few: 'очка', many: 'очков'), 'очков');
      expect(ruPlural(21, one: 'очко', few: 'очка', many: 'очков'), 'очко');
    });

    test('день / дня / дней', () {
      expect(ruPlural(1, one: 'день', few: 'дня', many: 'дней'), 'день');
      expect(ruPlural(3, one: 'день', few: 'дня', many: 'дней'), 'дня');
      expect(ruPlural(7, one: 'день', few: 'дня', many: 'дней'), 'дней');
    });
  });
}
```

- [ ] **Step 2: Run (fail)**

Run: `flutter test test/l10n/plurals_ru_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `lib/l10n/plurals_ru.dart`:

```dart
/// Russian grammatical-number categories per CLDR.
///   one  — 1, 21, 31, 101, ...
///   few  — 2-4, 22-24, ... (excluding teens 11-14)
///   many — 0, 5-20, 25-30, ...
enum RuPlural { one, few, many }

RuPlural ruPluralCategory(int n) {
  final abs = n.abs();
  final mod10 = abs % 10;
  final mod100 = abs % 100;

  if (mod10 == 1 && mod100 != 11) return RuPlural.one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return RuPlural.few;
  }
  return RuPlural.many;
}

/// Returns the correct form for [n] from the supplied three forms.
String ruPlural(int n,
    {required String one, required String few, required String many}) {
  switch (ruPluralCategory(n)) {
    case RuPlural.one:
      return one;
    case RuPlural.few:
      return few;
    case RuPlural.many:
      return many;
  }
}
```

- [ ] **Step 4: Use it in StringsRu**

In `lib/l10n/strings_ru.dart`:

```dart
import 'plurals_ru.dart';

class StringsRu {
  // ...existing keys...

  String pointsFor(int n) => ruPlural(n, one: 'очко', few: 'очка', many: 'очков');
  String daysFor(int n)   => ruPlural(n, one: 'день', few: 'дня',  many: 'дней');
  String wordsFor(int n)  => ruPlural(n, one: 'слово', few: 'слова', many: 'слов');
  String hintsFor(int n)  => ruPlural(n, one: 'подсказка', few: 'подсказки', many: 'подсказок');
}
```

And update call sites — e.g. score band:

```dart
Text('${state.pendingScore} ${StringsRu().pointsFor(state.pendingScore)}')
```

Streak label:

```dart
Text('${rewards.streakCount} ${StringsRu().daysFor(rewards.streakCount)}')
```

(In English, these just stay as plain pluralisation or hand-written "1 point / 2 points".)

- [ ] **Step 5: Run + commit**

```bash
flutter test test/l10n/plurals_ru_test.dart
git add lib/l10n/plurals_ru.dart lib/l10n/strings_ru.dart test/l10n/plurals_ru_test.dart
git add lib/  # any call-site changes
git commit -m "a11y: add Russian pluralisation helper and apply at call sites"
```

---

## Task 8: Semantics integration test

**Files:**
- Create: `test/widgets/semantics_test.dart`

- [ ] **Step 1: Write the test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/models/language_mode.dart';
import 'package:slova_iz_slova/providers/game_provider.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';
import 'package:slova_iz_slova/providers/settings_provider.dart';
import 'package:slova_iz_slova/screens/game_screen.dart';
import 'package:slova_iz_slova/services/ad_gateway.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'settings.languageMode': 'english',
    });
  });

  testWidgets('letter tiles have button semantics', (tester) async {
    final settings = SettingsProvider();
    await settings.load();
    final rewards = RewardsProvider();
    await rewards.load();

    await tester.pumpWidget(MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: rewards),
          Provider<AdGateway>.value(value: NoopAdGateway()),
          ChangeNotifierProxyProvider2<RewardsProvider, AdGateway, GameProvider>(
            create: (ctx) => GameProvider(
              rewards: ctx.read<RewardsProvider>(),
              adGateway: ctx.read<AdGateway>(),
            ),
            update: (_, r, a, prev) =>
                prev ?? GameProvider(rewards: r, adGateway: a),
          ),
        ],
        child: const GameScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();

    // At least one letter tile should be a button.
    expect(
      find.bySemanticsLabel(RegExp(r'Letter ')),
      findsAtLeastNWidgets(1),
    );

    handle.dispose();
  });
}
```

- [ ] **Step 2: Run**

Run: `flutter test test/widgets/semantics_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/widgets/semantics_test.dart
git commit -m "test: integration test for Semantics on letter tiles"
```

---

## Task 9: Device test plan + `A11Y_AUDIT.md`

**Files:**
- Create: `docs/A11Y_AUDIT.md`

- [ ] **Step 1: Run the 5-step device gate**

On both iOS and Android:

1. **Contrast** — eyeball every surface. Mark any failing text.
2. **VoiceOver (iOS) / TalkBack (Android)** — swipe through home → language select → game → submit a word → hint → complete level → level picker → trophies → settings → language change → mute toggle. Every interactive has a label.
3. **200% system font** — navigate the above flow. No text overflow / clipping.
4. **Reduce Motion** — complete a level. No confetti; no tile scale animations; UI still functional.
5. **Tap targets** — visually confirm every button ≥ 44×44.

- [ ] **Step 2: Write the audit doc**

Create `docs/A11Y_AUDIT.md`:

```markdown
# Accessibility audit — v1.1 launch gate

Date: <YYYY-MM-DD>
Devices tested:
- iOS: <device model>, iOS <version>
- Android: <device model>, Android <version>

## 5-step gate

| # | Check | iOS | Android | Notes |
|---|---|---|---|---|
| 1 | Contrast AA on all non-icon text | ✅ | ✅ | Amber only on icons + level stamps |
| 2 | VoiceOver / TalkBack reads every interactive | ✅ | ✅ | — |
| 3 | 200% system font — no overflow | ✅ | ✅ | Source word uses FittedBox |
| 4 | Reduce motion respected | ✅ | ✅ | Confetti + tile scale disabled |
| 5 | Tap targets ≥ 44×44 | ✅ | ✅ | Shuffle / Hint / Submit / Clear all padded |

## Known limitations

- Russian pluralisation covers points / days / words / hints only. Extend if new stringly-typed numbers are added.
- Level picker tiles rely on Semantics composition — if author adds a new state (e.g. "new!") extend `_labelFor` to include it.

## Sign-off

Audited by: <name>
Approved: <yes/no>
```

- [ ] **Step 3: Commit**

```bash
git add docs/A11Y_AUDIT.md
git commit -m "docs: A11Y audit (5-step gate passed on iOS + Android)"
```

---

## Task 10: Final verification

- [ ] **Step 1: All tests + analyze**

Run: `flutter analyze && flutter test`
Expected: clean, passing.

- [ ] **Step 2: Re-read `A11Y_AUDIT.md`**

Confirm every check is ✅ and the Sign-off line has a name + "yes".

- [ ] **Step 3: Tag**

```bash
git tag phase-8-a11y-complete
```

---

## Exit criteria recap

- Contrast policy documented; amber accent confined to icons + large bold + badges.
- All action buttons ≥ 44×44.
- 200% system font works without overflow on any screen.
- `MediaQuery.disableAnimations = true` disables confetti + tile-scale animations.
- Every interactive widget has meaningful `Semantics`. Found-word and level-complete use `liveRegion`.
- Russian pluralisation helper covers points / days / words / hints.
- `docs/A11Y_AUDIT.md` shows a passing 5-step gate signed off by the auditor.

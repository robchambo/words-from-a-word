import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slova_iz_slova/models/game_state.dart';
import 'package:slova_iz_slova/theme/app_theme.dart';
import 'package:slova_iz_slova/widgets/word_slot_item.dart';

void main() {
  testWidgets('revealed index renders the letter in accent colour', (tester) async {
    const tw = TargetWord(
      word: 'cat',
      length: 3,
      revealedIndices: {0},
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WordSlotItem(targetWord: tw),
        ),
      ),
    );

    final cText = find.text('C');
    expect(cText, findsOneWidget);
    // Unrevealed positions show an empty string.
    expect(find.text(''), findsWidgets);

    final textWidget = tester.widget<Text>(cText);
    expect(textWidget.style?.color, AppTheme.accent);
  });

  testWidgets('no indices revealed renders no letters', (tester) async {
    const tw = TargetWord(word: 'cat', length: 3);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WordSlotItem(targetWord: tw),
        ),
      ),
    );
    expect(find.text('C'), findsNothing);
    expect(find.text('A'), findsNothing);
    expect(find.text('T'), findsNothing);
  });

  testWidgets('found word shows every letter in slotFilled colour', (tester) async {
    const tw = TargetWord(word: 'cat', length: 3, isFound: true);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WordSlotItem(targetWord: tw),
        ),
      ),
    );
    expect(find.text('C'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('T'), findsOneWidget);
    // Found letters use the default condensedBold colour (foreground), not accent.
    final c = tester.widget<Text>(find.text('C'));
    expect(c.style?.color, isNot(AppTheme.accent));
  });
}

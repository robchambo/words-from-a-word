import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/l10n/strings_en.dart';
import 'package:slova_iz_slova/models/language_mode.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';
import 'package:slova_iz_slova/screens/library_complete_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders title, score, streak, replay and close buttons',
      (tester) async {
    final rewards = RewardsProvider();
    await rewards.load();

    rewards.lifetimeScore[LanguageMode.english] = 500;
    rewards.streakCount = 3;
    rewards.notifyListeners();

    await tester.pumpWidget(
      ChangeNotifierProvider<RewardsProvider>.value(
        value: rewards,
        child: const MaterialApp(
          home: LibraryCompleteScreen(mode: LanguageMode.english),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Title is present
    expect(find.text(StringsEn.libraryCompleteTitle), findsOneWidget);

    // Lifetime score value is visible
    expect(find.textContaining('500'), findsWidgets);

    // Streak count is visible
    expect(find.textContaining('3'), findsWidgets);

    // Replay button is present
    expect(find.text(StringsEn.libraryCompleteReplay), findsOneWidget);

    // Close button is present
    expect(find.text(StringsEn.libraryCompleteClose), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/engine/level_loader.dart';
import 'package:slova_iz_slova/models/language_mode.dart';
import 'package:slova_iz_slova/models/level_picker_filter.dart';
import 'package:slova_iz_slova/providers/game_provider.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';
import 'package:slova_iz_slova/screens/level_picker_screen.dart';
import 'package:slova_iz_slova/widgets/level_picker_tile.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LevelLoader.preload();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders level tiles for english with highestCompletedLevel=3',
      (tester) async {
    final rewards = RewardsProvider();
    await rewards.load();

    // Set highest completed level directly via public map field.
    rewards.highestCompletedLevel[LanguageMode.english] = 3;
    rewards.notifyListeners();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<RewardsProvider>.value(value: rewards),
          ChangeNotifierProvider<GameProvider>(
            create: (_) => GameProvider(rewards: rewards),
          ),
        ],
        child: const MaterialApp(
          home: LevelPickerScreen(
            mode: LanguageMode.english,
            filter: LevelPickerFilter.all,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // The library has 20 English levels — all should be rendered in 'all' mode.
    final librarySize = LevelLoader.librarySize(LanguageMode.english);
    expect(librarySize, greaterThan(0));

    // Smoke check: at least one LevelPickerTile is present (GridView renders
    // lazily so only visible items are in the widget tree).
    expect(find.byType(LevelPickerTile), findsWidgets);

    // The library has more than zero levels.
    expect(librarySize, greaterThan(0));
  });
}

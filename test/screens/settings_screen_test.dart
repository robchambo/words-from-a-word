import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/providers/rewards_provider.dart';
import 'package:slova_iz_slova/providers/settings_provider.dart';
import 'package:slova_iz_slova/screens/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(
    Widget child,
    SettingsProvider settings,
    RewardsProvider rewards,
  ) {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: rewards),
        ],
        child: child,
      ),
    );
  }

  testWidgets('renders six stub rows', (tester) async {
    final settings = SettingsProvider();
    await settings.load();
    final rewards = RewardsProvider();
    await rewards.load();

    await tester.pumpWidget(wrap(const SettingsScreen(), settings, rewards));

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('How to play'), findsOneWidget);
    expect(find.text('Mute sounds'), findsOneWidget);
    expect(find.text('Remove ads'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
  });

  testWidgets('Phase-1-disabled rows are dimmed', (tester) async {
    final settings = SettingsProvider();
    await settings.load();
    final rewards = RewardsProvider();
    await rewards.load();

    await tester.pumpWidget(wrap(const SettingsScreen(), settings, rewards));

    // Privacy row is still disabled in Phase 5 (Remove ads / Restore are now
    // enabled). Expect it to be wrapped in an Opacity.
    final privacyRow = find.ancestor(
      of: find.text('Privacy policy'),
      matching: find.byType(Opacity),
    );
    expect(privacyRow, findsOneWidget);
  });
}

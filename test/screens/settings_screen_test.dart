import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/providers/settings_provider.dart';
import 'package:slova_iz_slova/screens/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child, SettingsProvider settings) {
    return MaterialApp(
      home: ChangeNotifierProvider.value(
        value: settings,
        child: child,
      ),
    );
  }

  testWidgets('renders six stub rows', (tester) async {
    final settings = SettingsProvider();
    await settings.load();

    await tester.pumpWidget(wrap(const SettingsScreen(), settings));

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

    await tester.pumpWidget(wrap(const SettingsScreen(), settings));

    // Mute row is Phase 1-disabled (enabled in Phase 4). Remove-ads / Restore /
    // Privacy also disabled here.
    final muteRow = find.ancestor(
      of: find.text('Mute sounds'),
      matching: find.byType(Opacity),
    );
    expect(muteRow, findsOneWidget);
  });
}

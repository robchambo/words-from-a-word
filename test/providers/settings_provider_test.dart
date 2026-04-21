import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slova_iz_slova/providers/settings_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('muted defaults to false', () async {
    final p = SettingsProvider();
    await p.load();

    expect(p.muted, isFalse);
  });

  test('setMuted persists and notifies', () async {
    final p = SettingsProvider();
    await p.load();

    var ticks = 0;
    p.addListener(() => ticks++);

    await p.setMuted(true);

    expect(p.muted, isTrue);
    expect(ticks, 1);

    final p2 = SettingsProvider();
    await p2.load();
    expect(p2.muted, isTrue);
  });
}

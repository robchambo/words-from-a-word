import 'package:flutter_test/flutter_test.dart';
import 'package:slova_iz_slova/engine/level_loader.dart';
import 'package:slova_iz_slova/models/language_mode.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LevelLoader.preload();
  });

  group('LevelLoader.generateLevel', () {
    test('returns a valid level for level 1', () {
      final level = LevelLoader.generateLevel(1, LanguageMode.english);
      expect(level.levelNumber, greaterThan(0));
      expect(level.sourceWord, isNotEmpty);
    });

    test('throws LevelNotFoundException beyond library bounds', () {
      final size = LevelLoader.librarySize(LanguageMode.english);
      expect(
        () => LevelLoader.generateLevel(size + 1, LanguageMode.english),
        throwsA(isA<LevelNotFoundException>()),
      );
    });
  });
}

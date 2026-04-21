import 'package:flutter_test/flutter_test.dart';
import 'package:slova_iz_slova/engine/game_engine.dart';

void main() {
  test('scoreWord regular: length × 10 + length-bonus', () {
    expect(GameEngine.scoreWord('cat', isBonus: false), 30);         // 3×10 + 0
    expect(GameEngine.scoreWord('berry', isBonus: false), 70);       // 5×10 + 20
    expect(GameEngine.scoreWord('strawberry', isBonus: false), 130); // 10×10 + 30
  });

  test('scoreWord bonus returns flat 15 regardless of length', () {
    expect(GameEngine.scoreWord('cat', isBonus: true), 15);
    expect(GameEngine.scoreWord('strawberry', isBonus: true), 15);
  });
}

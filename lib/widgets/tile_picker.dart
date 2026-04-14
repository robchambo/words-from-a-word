import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import 'letter_tile.dart';

class TilePicker extends StatelessWidget {
  final GameState state;

  const TilePicker({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameProvider>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Current word display
        Container(
          height: 48,
          alignment: Alignment.center,
          child: state.currentInput.isEmpty
              ? Text(
                  '',
                  style: AppTheme.displayMedium,
                )
              : _buildCurrentWord(state),
        ),
        const SizedBox(height: 12),

        // Tile grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: state.level.sourceLetters.map((tile) {
            return LetterTileWidget(
              letter: tile.letter,
              isSelected: tile.isSelected,
              isUsed: tile.isUsed,
              isHinted: state.hintedLetterCounts.containsKey(tile.letter),
              onTap: () {
                if (tile.isSelected) {
                  game.deselectTile(tile.id);
                } else {
                  game.selectTile(tile.id);
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Clear button
            _circleButton(
              icon: Icons.refresh,
              onTap: game.clearSelection,
            ),
            const SizedBox(width: 16),

            // Check button
            ElevatedButton(
              onPressed:
                  state.currentInput.length >= 3 ? game.submitWord : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.primaryFg,
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    state.currentInput.length >= 3 ? '' : '',
                    style: AppTheme.condensedBold.copyWith(
                      color: AppTheme.primaryFg,
                      fontSize: 16,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Shuffle button
            _circleButton(
              icon: Icons.shuffle,
              onTap: game.shuffleTiles,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentWord(GameState state) {
    Widget word = Text(
      state.currentInput.toUpperCase(),
      style: AppTheme.displayMedium.copyWith(
        letterSpacing: 4,
        fontSize: 24,
      ),
    );

    if (state.isShaking) {
      word = word
          .animate(onPlay: (c) => c.forward())
          .shakeX(
            duration: 350.ms,
            hz: 4,
            amount: 6,
          );
    }

    return word;
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border),
          color: AppTheme.card,
        ),
        child: Icon(icon, color: AppTheme.foreground, size: 20),
      ),
    );
  }
}

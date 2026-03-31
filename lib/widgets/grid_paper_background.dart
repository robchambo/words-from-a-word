import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GridPaperBackground extends StatelessWidget {
  final Widget child;

  const GridPaperBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPaperPainter(
              lineColor: AppTheme.border.withValues(alpha: 0.5),
              cellSize: 20.0,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _GridPaperPainter extends CustomPainter {
  final Color lineColor;
  final double cellSize;

  _GridPaperPainter({required this.lineColor, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.5;

    for (double x = 0; x <= size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPaperPainter old) => false;
}

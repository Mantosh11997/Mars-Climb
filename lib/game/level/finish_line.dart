import 'dart:ui';

import 'package:flame/components.dart';

import '../config.dart';
import '../terrain/terrain_generator.dart';

/// The checkered banner at the end of the course.
///
/// Purely decorative - the win itself is decided by the rover's x in
/// [MarsClimbGame.update], so a fast rover can never tunnel past a sensor
/// and miss the finish.
class FinishLine extends PositionComponent {
  FinishLine({required this.generator}) {
    priority = 2;
  }

  final TerrainGenerator generator;

  static const double _poleHeight = 5.2;
  static const double _bannerHeight = 1.15;
  static const double _bannerWidth = 3.0;
  static const int _checkCols = 6;
  static const int _checkRows = 2;

  @override
  Future<void> onLoad() async {
    final x = generator.level.finishX;
    position = Vector2(x, generator.surfaceY(x));
  }

  @override
  void render(Canvas canvas) {
    final polePaint = Paint()
      ..color = const Color(0xFFE8E4DE)
      ..strokeWidth = 0.16
      ..strokeCap = StrokeCap.round;

    // Pole, standing on the ground at the component's origin.
    canvas.drawLine(Offset.zero, const Offset(0, -_poleHeight), polePaint);

    // Checkered banner hanging off the top.
    const cw = _bannerWidth / _checkCols;
    const ch = _bannerHeight / _checkRows;
    const top = -_poleHeight;

    for (var row = 0; row < _checkRows; row++) {
      for (var col = 0; col < _checkCols; col++) {
        final dark = (row + col).isEven;
        canvas.drawRect(
          Rect.fromLTWH(col * cw, top + row * ch, cw, ch),
          Paint()
            ..color = dark ? const Color(0xFF241713) : const Color(0xFFF3EFE9),
        );
      }
    }

    // Ground marker so the line is readable even at speed.
    canvas.drawRect(
      const Rect.fromLTWH(-0.18, -0.5, 0.36, 0.5),
      Paint()..color = GameConfig.accent,
    );
  }
}

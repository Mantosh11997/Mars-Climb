import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/level/level.dart';
import '../game/level/level_stats.dart';

/// Draws a course's real silhouette, taken from the terrain generator.
class LevelProfile extends StatelessWidget {
  const LevelProfile({super.key, required this.level, this.height});

  final Level level;

  /// Fixed height, or null to fill the space the parent gives it (put it
  /// in an Expanded).
  final double? height;

  @override
  Widget build(BuildContext context) {
    final painter = CustomPaint(
      size: Size.infinite,
      painter: _ProfilePainter(LevelStats.of(level).profile),
    );
    if (height == null) return SizedBox(width: double.infinity, child: painter);
    return SizedBox(height: height, width: double.infinity, child: painter);
  }
}

class _ProfilePainter extends CustomPainter {
  _ProfilePainter(this.profile);

  final List<double> profile;

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.length < 2 || size.width <= 0) return;

    // Leave headroom so peaks don't clip the top of the card.
    const topPad = 8.0;
    final usable = size.height - topPad;

    final path = Path()..moveTo(0, size.height);
    for (var i = 0; i < profile.length; i++) {
      final x = size.width * i / (profile.length - 1);
      path.lineTo(x, topPad + profile[i] * usable);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            GameConfig.accent.withOpacity(0.55),
            GameConfig.accent.withOpacity(0.12),
          ],
        ).createShader(Offset.zero & size),
    );

    // Crust line along the top edge of the silhouette.
    final crust = Path()..moveTo(0, topPad + profile.first * usable);
    for (var i = 1; i < profile.length; i++) {
      crust.lineTo(
        size.width * i / (profile.length - 1),
        topPad + profile[i] * usable,
      );
    }
    canvas.drawPath(
      crust,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = GameConfig.groundCrust
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ProfilePainter oldDelegate) =>
      oldDelegate.profile != profile;
}

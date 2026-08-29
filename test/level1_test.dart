import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/config.dart';
import 'package:mars_climb/game/level/level.dart';
import 'package:mars_climb/game/terrain/terrain_generator.dart';

/// Geometry checks for level 1.
///
/// The physics can only be judged by playing, but the *course* can be
/// checked here: that both ends are flat, that the terrain is continuous,
/// and above all that no slope is steep enough to make the level
/// impossible to finish.
void main() {
  final gen = TerrainGenerator(level1);

  double slopeDegAt(double x) =>
      math.atan(gen.slopeAt(x).abs()) * 180 / math.pi;

  test('starting apron is flat so the rover can spawn and settle', () {
    for (var x = 0.0; x <= GameConfig.terrainFlatRunway; x += 0.5) {
      expect(gen.surfaceY(x), closeTo(GameConfig.terrainBaseY, 1e-9),
          reason: 'apron should be dead flat at x=$x');
    }
  });

  test('finish line sits on flat ground', () {
    final finish = level1.finishX;
    for (var x = finish - 2; x <= level1.worldEndX; x += 0.5) {
      expect(gen.surfaceY(x), closeTo(GameConfig.terrainBaseY, 0.05),
          reason: 'ground near/after the finish should be flat at x=$x');
    }
  });

  test('surface is continuous - no cliffs between sample points', () {
    const step = GameConfig.terrainPointSpacing;
    var worstJump = 0.0;
    for (var x = 0.0; x < level1.worldEndX; x += step) {
      final jump = (gen.surfaceY(x + step) - gen.surfaceY(x)).abs();
      worstJump = math.max(worstJump, jump);
    }
    // A jump bigger than the wheel radius would be a wall, not a hill.
    expect(worstJump, lessThan(GameConfig.wheelRadius),
        reason: 'largest step between adjacent vertices was $worstJump m');
  });

  test('level 1 is climbable - slopes stay inside the rover\'s grip', () {
    // Box2D mixes two fixtures' friction as sqrt(a*b). A driven wheel can
    // hold a slope while tan(angle) <= that combined coefficient, so this
    // is the hard physical ceiling for a standing start.
    final mu = math.sqrt(GameConfig.wheelFriction * GameConfig.terrainFriction);
    final gripLimitDeg = math.atan(mu) * 180 / math.pi;

    // Design margin. The ceiling assumes ideal grip, full torque and a
    // level-headed rover; in practice the course is taken at speed, the
    // helmet makes it top-heavy, and slopes are met at bad angles.
    const margin = 0.62;
    final budgetDeg = gripLimitDeg * margin;

    var worstDeg = 0.0;
    var worstX = 0.0;
    for (var x = 0.0; x < level1.finishX; x += 0.25) {
      final deg = slopeDegAt(x);
      if (deg > worstDeg) {
        worstDeg = deg;
        worstX = x;
      }
    }

    // ignore: avoid_print
    print('grip ceiling ${gripLimitDeg.toStringAsFixed(1)}deg, '
        'design budget ${budgetDeg.toStringAsFixed(1)}deg, '
        'steepest on level 1 ${worstDeg.toStringAsFixed(1)}deg '
        'at x=${worstX.toStringAsFixed(1)}m');

    expect(worstDeg, lessThan(budgetDeg),
        reason: 'level 1 is the shakedown course - it should never need a '
            'run-up, and never strand a rover that stops on a hill');
  });

  test('course profile', () {
    const rows = 15;
    const cols = 110;
    final grid = List.generate(rows, (_) => List.filled(cols, ' '));

    var minY = 0.0;
    var maxY = 0.0;
    for (var c = 0; c < cols; c++) {
      final y = gen.surfaceY(level1.worldEndX * c / (cols - 1));
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    final span = math.max(maxY - minY, 0.001);

    for (var c = 0; c < cols; c++) {
      final x = level1.worldEndX * c / (cols - 1);
      final y = gen.surfaceY(x);
      final r = (((y - minY) / span) * (rows - 1)).round().clamp(0, rows - 1);
      for (var rr = r; rr < rows; rr++) {
        grid[rr][c] = rr == r ? '-' : '#';
      }
    }

    final finishCol =
        ((level1.finishX / level1.worldEndX) * (cols - 1)).round();
    for (var rr = 0; rr < rows; rr++) {
      if (grid[rr][finishCol] == ' ') grid[rr][finishCol] = '|';
    }

    // ignore: avoid_print
    print('\n${level1.name} — ${level1.length.toInt()} m '
        '(| = finish, height span ${span.toStringAsFixed(1)} m)');
    for (final row in grid) {
      // ignore: avoid_print
      print(row.join());
    }
  });
}

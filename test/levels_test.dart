import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/config.dart';
import 'package:mars_climb/game/level/level.dart';
import 'package:mars_climb/game/terrain/terrain_generator.dart';

/// Geometry checks for every course.
///
/// The physics can only be judged by playing, but the *courses* can be
/// checked here: both ends flat, no cliffs between chain vertices, no
/// vertices so close that Forge2D refuses the chain, and no slope steeper
/// than the level's declared difficulty allows.
void main() {
  /// Box2D mixes two fixtures' friction as sqrt(a*b). A driven wheel holds
  /// a slope while tan(angle) <= that coefficient, so this is the hard
  /// physical ceiling for a standing start on any course.
  final gripCeilingDeg = math.atan(
        math.sqrt(GameConfig.wheelFriction * GameConfig.terrainFriction),
      ) *
      180 /
      math.pi;

  test('grip ceiling', () {
    // ignore: avoid_print
    print('rover grip ceiling: ${gripCeilingDeg.toStringAsFixed(1)}deg');
    expect(gripCeilingDeg, greaterThan(30));
  });

  for (final level in levels) {
    final gen = TerrainGenerator(level);

    group('${level.number}. ${level.name}', () {
      test('starting apron is flat so the rover can spawn and settle', () {
        for (var x = 0.0; x <= GameConfig.terrainFlatRunway; x += 0.5) {
          expect(gen.surfaceY(x), closeTo(GameConfig.terrainBaseY, 1e-9));
        }
      });

      test('finish line and run-out are dead flat', () {
        // Hill amplitude ramps to exactly zero at the finish, so the
        // banner and the whole run-out sit on flat, landable ground.
        for (var x = level.finishX; x <= level.worldEndX; x += 0.5) {
          expect(gen.surfaceY(x), closeTo(GameConfig.terrainBaseY, 1e-9),
              reason: 'ground at $x m should be flat');
        }
      });

      test('surface is continuous - no cliffs between sample points', () {
        // A legitimately steep hill still steps a long way between two
        // vertices, so compare against what the rover could physically
        // hold rather than against the wheel radius - otherwise this just
        // duplicates the steepness check and fires on honest terrain.
        const step = GameConfig.terrainPointSpacing;
        final maxHonestJump = step * math.tan(gripCeilingDeg * math.pi / 180);

        var worstJump = 0.0;
        for (var x = 0.0; x < level.worldEndX; x += step) {
          worstJump = math.max(
            worstJump,
            (gen.surfaceY(x + step) - gen.surfaceY(x)).abs(),
          );
        }
        expect(worstJump, lessThan(maxHonestJump),
            reason: 'a ${worstJump.toStringAsFixed(2)} m step between '
                'adjacent vertices is a cliff, not a hill');
      });

      test('no chain vertices too close for Forge2D', () {
        // createChain THROWS on vertices closer than forge2d's linear slop,
        // inside BodyComponent.onLoad - so the chunk silently never mounts
        // and the world gets a hole. This is what made terrain stop dead
        // at x=42 m.
        const chunkWidth = GameConfig.terrainChunkWidth;
        final maxIndex = (level.worldEndX / chunkWidth).ceil() - 1;

        var worst = double.infinity;
        for (var i = 0; i <= maxIndex; i++) {
          final pts = gen.sample(i * chunkWidth, (i + 1) * chunkWidth);
          for (var k = 1; k < pts.length; k++) {
            worst = math.min(worst, (pts[k] - pts[k - 1]).length);
          }
        }
        expect(worst, greaterThan(TerrainGenerator.minVertexSeparation * 0.9),
            reason: 'vertices this close make createChain throw, which '
                'silently drops the whole chunk out of the world');
      });

      test('stays inside its declared difficulty budget', () {
        final budgetDeg = gripCeilingDeg * level.slopeBudget;

        // Measure the real chain segments. A central difference smooths
        // over the steepest single segment and reports the course as
        // easier than the wheels actually find it.
        const step = GameConfig.terrainPointSpacing;
        var worstDeg = 0.0;
        var worstX = 0.0;
        for (var x = 0.0; x < level.finishX; x += step) {
          final dy = gen.surfaceY(x + step) - gen.surfaceY(x);
          final deg = math.atan(dy.abs() / step) * 180 / math.pi;
          if (deg > worstDeg) {
            worstDeg = deg;
            worstX = x;
          }
        }

        // ignore: avoid_print
        print('${level.number}. ${level.name.padRight(16)} '
            'len ${level.length.toInt().toString().padLeft(3)}m  '
            'budget ${budgetDeg.toStringAsFixed(1).padLeft(4)}deg  '
            'steepest ${worstDeg.toStringAsFixed(1).padLeft(4)}deg '
            'at ${worstX.toStringAsFixed(0).padLeft(3)}m');

        expect(worstDeg, lessThan(budgetDeg),
            reason: 'level ${level.number} is steeper than its slopeBudget '
                'allows - either ease the terrain or raise the budget '
                'deliberately');
      });
    });
  }

  test('difficulty rises across the campaign', () {
    for (var i = 1; i < levels.length; i++) {
      expect(levels[i].length, greaterThan(levels[i - 1].length),
          reason: 'courses should get longer as the campaign goes on');
    }
  });

  test('course profiles', () {
    for (final level in levels) {
      final gen = TerrainGenerator(level);
      const rows = 11;
      const cols = 104;
      final grid = List.generate(rows, (_) => List.filled(cols, ' '));

      var minY = 0.0;
      var maxY = 0.0;
      for (var c = 0; c < cols; c++) {
        final y = gen.surfaceY(level.worldEndX * c / (cols - 1));
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
      final span = math.max(maxY - minY, 0.001);

      for (var c = 0; c < cols; c++) {
        final y = gen.surfaceY(level.worldEndX * c / (cols - 1));
        final r = (((y - minY) / span) * (rows - 1)).round().clamp(0, rows - 1);
        for (var rr = r; rr < rows; rr++) {
          grid[rr][c] = rr == r ? '-' : '#';
        }
      }
      final finishCol =
          ((level.finishX / level.worldEndX) * (cols - 1)).round();
      for (var rr = 0; rr < rows; rr++) {
        if (grid[rr][finishCol] == ' ') grid[rr][finishCol] = '|';
      }

      // ignore: avoid_print
      print('\n${level.number}. ${level.name} - ${level.length.toInt()} m, '
          'relief ${span.toStringAsFixed(1)} m');
      for (final row in grid) {
        // ignore: avoid_print
        print(row.join());
      }
    }
  });
}

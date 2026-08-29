import 'package:flame/components.dart';

import '../config.dart';
import '../level/level.dart';
import 'noise.dart';

/// Pure function-style terrain source for one level.
///
/// This is the single source of truth for "how high is the ground at x?".
/// Chunks, collectibles, the finish line and the rover spawn all query the
/// same function, so nothing can ever disagree about where the surface is.
class TerrainGenerator {
  TerrainGenerator(this.level) : _noise = ValueNoise1D(level.seed);

  final Level level;
  final ValueNoise1D _noise;

  /// Surface y for a given world x. Remember: y-down, so a *smaller*
  /// value is a *higher* hill.
  double surfaceY(double x) {
    final scale = _amplitudeScale(x);
    if (scale <= 0) return GameConfig.terrainBaseY;

    final n = _noise.fbm(
      x / level.wavelength,
      octaves: GameConfig.terrainOctaves,
      persistence: GameConfig.terrainPersistence,
      lacunarity: GameConfig.terrainLacunarity,
    );

    // Negative because up == -y.
    return GameConfig.terrainBaseY - n * level.amplitude * scale;
  }

  /// Hills ease in after the starting apron and ease back out before the
  /// finish, so both ends of the course are flat and landable.
  double _amplitudeScale(double x) {
    final rampIn = smoothClamp01(
      (x - GameConfig.terrainFlatRunway) / GameConfig.terrainRampDistance,
    );
    final rampOut = smoothClamp01(
      (level.finishX - x) / Level.finishFlattenDistance,
    );
    return rampIn * rampOut;
  }

  /// Surface slope, handy for orienting props on the ground.
  double slopeAt(double x, {double eps = 0.25}) =>
      (surfaceY(x + eps) - surfaceY(x - eps)) / (2 * eps);

  /// The lowest (largest y) the ground ever gets on this course. Used to
  /// decide when the rover has fallen out of the world.
  double get lowestGroundY => GameConfig.terrainBaseY + level.amplitude;

  /// Sample the surface across [fromX, toX] inclusive, at the configured
  /// spacing. The end point is always included so adjacent chunks share
  /// an exact vertex and leave no seam.
  List<Vector2> sample(double fromX, double toX) {
    final points = <Vector2>[];
    const spacing = GameConfig.terrainPointSpacing;

    for (var x = fromX; x < toX; x += spacing) {
      points.add(Vector2(x, surfaceY(x)));
    }
    points.add(Vector2(toX, surfaceY(toX)));

    return points;
  }
}

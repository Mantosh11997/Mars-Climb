import 'package:flame/components.dart';

import '../config.dart';
import 'noise.dart';

/// Pure function-style terrain source.
///
/// This is the single source of truth for "how high is the ground at x?".
/// Chunks, collectibles and the rover spawn all query the *same* function,
/// so nothing can ever disagree about where the surface is.
class TerrainGenerator {
  TerrainGenerator({int seed = GameConfig.terrainSeed})
      : _noise = ValueNoise1D(seed);

  final ValueNoise1D _noise;

  /// Surface y for a given world x. Remember: y-down, so a *smaller*
  /// value is a *higher* hill.
  double surfaceY(double x) {
    // Flat runway at the start so the rover can spawn and settle.
    if (x <= GameConfig.terrainFlatRunway) {
      return GameConfig.terrainBaseY;
    }

    // Ease the hills in rather than hitting a wall at the runway's end.
    final ramp = smoothClamp01(
      (x - GameConfig.terrainFlatRunway) / GameConfig.terrainRampDistance,
    );

    final n = _noise.fbm(
      x / GameConfig.terrainWavelength,
      octaves: GameConfig.terrainOctaves,
      persistence: GameConfig.terrainPersistence,
      lacunarity: GameConfig.terrainLacunarity,
    );

    // Negative because up == -y.
    return GameConfig.terrainBaseY - n * GameConfig.terrainAmplitude * ramp;
  }

  /// Surface normal-ish slope, handy for orienting props on the ground.
  double slopeAt(double x, {double eps = 0.25}) =>
      (surfaceY(x + eps) - surfaceY(x - eps)) / (2 * eps);

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

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

    // Detail: the bumps and ridges.
    final detail = _noise.fbm(
      x / level.wavelength,
      octaves: GameConfig.terrainOctaves,
      persistence: GameConfig.terrainPersistence,
      lacunarity: GameConfig.terrainLacunarity,
    );

    // Macro: a long wave underneath, which is what makes a climb a climb
    // rather than a bump. Offset so it does not share lattice points with
    // the detail noise and accidentally line up with it.
    final macro = _noise.fbm(
      x / (level.wavelength * level.macroWavelengthFactor) + 91.7,
      octaves: 2,
      persistence: 0.5,
      lacunarity: 2.0,
    );

    final height =
        detail * level.amplitude + macro * level.amplitude * level.macroScale;

    // Negative because up == -y.
    return GameConfig.terrainBaseY - height * scale;
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
  /// decide when the rover has fallen out of the world. Must account for
  /// the macro wave as well as the detail, or a deep valley reads as
  /// falling off the map.
  double get lowestGroundY =>
      GameConfig.terrainBaseY + level.amplitude * (1 + level.macroScale);

  /// Forge2D rejects a chain whose adjacent vertices are closer than its
  /// linear slop (0.005 m), and `createChain` throws rather than skipping
  /// them. A throw here happens inside `BodyComponent.onLoad`, so the
  /// chunk silently never mounts and the world gets a hole in it.
  ///
  /// This margin is 10x that limit.
  static const double minVertexSeparation = 0.05;

  /// Sample the surface across [fromX, toX] inclusive, at the configured
  /// spacing. The end point is always included so adjacent chunks share
  /// an exact vertex and leave no seam.
  List<Vector2> sample(double fromX, double toX) {
    const spacing = GameConfig.terrainPointSpacing;
    final points = <Vector2>[];

    // x is computed from the index rather than accumulated with `x +=`.
    // Accumulating drifts, and when the span divides evenly by the spacing
    // - which it does exactly, 42 / 0.6 == 70 - the last step lands within
    // floating-point dust of toX. Appending toX then produced a duplicate
    // vertex, createChain threw, and that chunk never appeared.
    final steps = ((toX - fromX) / spacing).floor();
    for (var i = 0; i <= steps; i++) {
      final x = fromX + i * spacing;
      if (x >= toX - minVertexSeparation) break;
      points.add(Vector2(x, surfaceY(x)));
    }
    points.add(Vector2(toX, surfaceY(toX)));

    return points;
  }
}

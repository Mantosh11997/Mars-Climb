import 'dart:math' as math;

import '../config.dart';
import '../terrain/terrain_generator.dart';
import 'level.dart';

/// Summary numbers for a course, computed from the same generator the
/// game drives on - so the level select can never advertise a course that
/// differs from the one you play.
///
/// Computing these walks the whole course, so results are memoised per
/// level rather than recomputed on every widget build.
class LevelStats {
  const LevelStats({
    required this.maxGradeDeg,
    required this.reliefMetres,
    required this.profile,
  });

  /// Steepest single chain segment, in degrees.
  final double maxGradeDeg;

  /// Peak-to-trough height range across the course, in metres.
  final double reliefMetres;

  /// Normalised course silhouette: x in 0..1 across the course, y in 0..1
  /// where 0 is the highest point and 1 the lowest. Ready to scale into
  /// any rectangle.
  final List<double> profile;

  static final Map<int, LevelStats> _cache = {};

  static LevelStats of(Level level) =>
      _cache.putIfAbsent(level.number, () => _compute(level));

  static LevelStats _compute(Level level) {
    final gen = TerrainGenerator(level);
    const step = GameConfig.terrainPointSpacing;

    var maxGrade = 0.0;
    for (var x = 0.0; x < level.finishX; x += step) {
      final dy = gen.surfaceY(x + step) - gen.surfaceY(x);
      maxGrade = math.max(maxGrade, math.atan(dy.abs() / step));
    }

    const samples = 108;
    final ys = <double>[];
    var minY = double.infinity;
    var maxY = -double.infinity;
    for (var i = 0; i < samples; i++) {
      final y = gen.surfaceY(level.worldEndX * i / (samples - 1));
      ys.add(y);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }

    final span = math.max(maxY - minY, 0.001);
    return LevelStats(
      maxGradeDeg: maxGrade * 180 / math.pi,
      reliefMetres: span,
      // y is already down-positive, so this maps high ground to 0.
      profile: [for (final y in ys) (y - minY) / span],
    );
  }
}

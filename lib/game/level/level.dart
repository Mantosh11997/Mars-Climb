import '../config.dart';

/// A single, finite course.
///
/// Everything that distinguishes one level from another lives here, so
/// adding level 2 is a matter of writing another const - not touching the
/// terrain, camera or vehicle code.
class Level {
  const Level({
    required this.number,
    required this.name,
    required this.subtitle,
    required this.length,
    required this.seed,
    this.amplitude = GameConfig.terrainAmplitude,
    this.wavelength = GameConfig.terrainWavelength,
    this.cellSpacing = GameConfig.cellSpacing,
    this.oxygenIdleDrain = GameConfig.oxygenIdleDrain,
    this.oxygenThrottleDrain = GameConfig.oxygenThrottleDrain,
  });

  final int number;
  final String name;
  final String subtitle;

  /// Distance in metres from the start line to the finish line.
  final double length;

  /// Terrain seed. Change it and the whole course changes.
  final int seed;

  /// Hill height (metres) and hill length (metres).
  final double amplitude;
  final double wavelength;

  /// Average metres between energy cells.
  final double cellSpacing;

  final double oxygenIdleDrain;
  final double oxygenThrottleDrain;

  /// Flat ground past the finish line so the rover has room to stop.
  static const double runOut = 34.0;

  /// Hills fade out over the last stretch, so the finish line always sits
  /// on flat, landable ground.
  static const double finishFlattenDistance = 26.0;

  /// The rover spawns here, on the flat starting apron.
  static const double startX = 9.0;

  /// x of the finish line.
  double get finishX => length;

  /// Last x that has ground under it. Past this is the void.
  double get worldEndX => length + runOut;
}

/// -------------------------------------------------------------------
/// LEVEL 1
/// -------------------------------------------------------------------
const Level level1 = Level(
  number: 1,
  name: 'Acidalia Flats',
  subtitle: 'Shakedown run. Rolling dunes, a soft start, and just enough '
      'air to get you into trouble.',
  length: 520,
  seed: 20260829,
  amplitude: 4.9,
  wavelength: 22.0,
  cellSpacing: 16.0,
);

/// Every level in play order. Level 1 is the only finished course so far;
/// append here and the rest of the game picks it up.
const List<Level> levels = [level1];

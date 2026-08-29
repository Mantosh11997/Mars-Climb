import '../config.dart';

/// A single, finite course.
///
/// Everything that distinguishes one level from another lives here, so
/// adding a course is a matter of writing another const - no changes to
/// the terrain, camera or vehicle code.
class Level {
  const Level({
    required this.number,
    required this.name,
    required this.subtitle,
    required this.length,
    required this.seed,
    required this.amplitude,
    required this.wavelength,
    required this.slopeBudget,
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

  /// Hill height (metres) and hill length (metres). Steepness is roughly
  /// amplitude / wavelength, so shrinking the wavelength bites harder than
  /// raising the amplitude.
  final double amplitude;
  final double wavelength;

  /// How steep this course is *allowed* to get, as a fraction of the
  /// rover's physical grip ceiling (see levels_test).
  ///
  /// This is the difficulty dial. 0.6 is a shakedown that never strands
  /// you; 0.9 will punish a bad line and demands momentum. Above 1.0 the
  /// course is literally unclimbable, and the test fails.
  final double slopeBudget;

  /// Average metres between energy cells. Longer courses need these to
  /// keep the oxygen clock survivable.
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
/// THE COURSES
///
/// Ordered by difficulty. Each one is meant to feel different, not just
/// longer: the wavelength sets the rhythm and the slopeBudget sets how
/// much the course is allowed to fight you.
/// -------------------------------------------------------------------

const Level level1 = Level(
  number: 1,
  name: 'Acidalia Flats',
  subtitle: 'Shakedown run. Rolling dunes, a soft start, and just enough '
      'air to get you into trouble.',
  length: 520,
  seed: 20260829,
  amplitude: 4.42,
  wavelength: 22.0,
  slopeBudget: 0.62,
  cellSpacing: 16.0,
);

const Level level2 = Level(
  number: 2,
  name: 'Chryse Ripples',
  subtitle: 'Short, choppy ridges that never let the suspension settle. '
      'Keep the throttle honest or you will bounce off the line.',
  length: 640,
  seed: 771402,
  amplitude: 3.63,
  wavelength: 16.5,
  slopeBudget: 0.74,
  cellSpacing: 17.0,
  oxygenIdleDrain: 1.8,
);

const Level level3 = Level(
  number: 3,
  name: 'Tharsis Rollers',
  subtitle: 'Long, heavy swells. Carry speed over the crests and the rover '
      'flies - land it nose-down and the helmet finds the regolith.',
  length: 780,
  seed: 5583019,
  amplitude: 7.88,
  wavelength: 38.0,
  slopeBudget: 0.72,
  cellSpacing: 19.0,
  oxygenIdleDrain: 1.7,
  oxygenThrottleDrain: 3.1,
);

const Level level4 = Level(
  number: 4,
  name: 'Olympus Ascent',
  subtitle: 'The steep one. Tight walls of regolith with no room to build '
      'a run-up. Stall on a face and the climb is over.',
  length: 900,
  seed: 41209773,
  amplitude: 4.87,
  wavelength: 19.0,
  slopeBudget: 0.88,
  cellSpacing: 15.0,
  oxygenIdleDrain: 2.0,
  oxygenThrottleDrain: 3.8,
);

/// Every level, in play order.
const List<Level> levels = [level1, level2, level3, level4];

/// The next course after [level], or null if it is the last one.
Level? levelAfter(Level level) {
  final i = levels.indexWhere((l) => l.number == level.number);
  if (i < 0 || i + 1 >= levels.length) return null;
  return levels[i + 1];
}

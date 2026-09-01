import '../config.dart';
import 'theme.dart';

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
    required this.theme,
    this.macroScale = 0.85,
    this.macroWavelengthFactor = 5.0,
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
  /// A second, much longer wave laid under the detail noise, as a fraction
  /// of [amplitude]. This is what produces sustained climbs rather than a
  /// field of ripples you can carry momentum straight over - without it a
  /// course is just chop, and chop is trivial at speed.
  final double macroScale;

  /// How many times longer that underlying wave is than [wavelength].
  final double macroWavelengthFactor;

  /// Measured against the *starter* machine's grip, so 1.0 means "right at
  /// the limit of what a Pathfinder can hold". Grippier machines can go
  /// beyond it and slippier ones cannot - levels_test reports which
  /// machines can clear each course.
  final double slopeBudget;

  /// Sky, scenery and ground palette. Each course gets its own so no two
  /// read as the same place.
  final LevelTheme theme;

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
  amplitude: 5.02,
  wavelength: 22.0,
  macroScale: 2.4,
  macroWavelengthFactor: 8.0,
  slopeBudget: 0.68,
  theme: duskPlains,
  cellSpacing: 16.0,
);

const Level level2 = Level(
  number: 2,
  name: 'Chryse Ripples',
  subtitle: 'Short, choppy ridges that never let the suspension settle. '
      'Keep the throttle honest or you will bounce off the line.',
  length: 640,
  seed: 771402,
  amplitude: 4.40,
  wavelength: 16.5,
  macroScale: 3.0,
  macroWavelengthFactor: 8.0,
  slopeBudget: 0.80,
  theme: noonBasin,
  cellSpacing: 17.0,
  oxygenIdleDrain: 2.0,
);

const Level level3 = Level(
  number: 3,
  name: 'Tharsis Rollers',
  subtitle: 'Long, heavy swells. Carry speed over the crests and the rover '
      'flies - land it nose-down and the helmet finds the regolith.',
  length: 780,
  seed: 5583019,
  amplitude: 6.47,
  wavelength: 38.0,
  macroScale: 3.2,
  macroWavelengthFactor: 9.0,
  slopeBudget: 0.78,
  theme: dustStorm,
  cellSpacing: 19.0,
  oxygenIdleDrain: 1.9,
  oxygenThrottleDrain: 3.4,
);

const Level level4 = Level(
  number: 4,
  name: 'Olympus Ascent',
  subtitle: 'The steep one. Tight walls of regolith with no room to build '
      'a run-up. Stall on a face and the climb is over.',
  length: 900,
  seed: 41209773,
  amplitude: 6.08,
  wavelength: 19.0,
  macroScale: 3.6,
  macroWavelengthFactor: 7.0,
  slopeBudget: 0.92,
  theme: polarNight,
  cellSpacing: 15.0,
  oxygenIdleDrain: 2.2,
  oxygenThrottleDrain: 4.0,
);

const Level level5 = Level(
  number: 5,
  name: 'Verdant Vale',
  subtitle: 'Not Mars at all. Grass to the horizon, pines on every crest, '
      'and the longest climb in the game hiding under all that green.',
  length: 1000,
  seed: 3140927,
  amplitude: 6.90,
  wavelength: 20.0,
  macroScale: 3.8,
  macroWavelengthFactor: 8.5,
  slopeBudget: 0.95,
  theme: meadowVale,
  cellSpacing: 18.0,
  oxygenIdleDrain: 1.7,
);

const Level level6 = Level(
  number: 6,
  name: 'Frostpine Ridge',
  subtitle: 'Snowfields above the treeline. Grip is the problem, not the '
      'gradient - the crust lets go the moment you ask too much of it.',
  length: 1100,
  seed: 8814402,
  amplitude: 6.20,
  wavelength: 24.0,
  macroScale: 3.4,
  macroWavelengthFactor: 9.0,
  slopeBudget: 0.86,
  theme: alpineSnow,
  cellSpacing: 19.0,
  oxygenIdleDrain: 1.9,
);

const Level level7 = Level(
  number: 7,
  name: 'Rustworks Yard',
  subtitle: 'A refinery built on spoil heaps. Short, mean pitches between '
      'the towers, and drums everywhere the ground levels out.',
  length: 1200,
  seed: 6027715,
  amplitude: 4.25,
  wavelength: 15.0,
  macroScale: 3.4,
  macroWavelengthFactor: 7.0,
  slopeBudget: 0.90,
  theme: refineryYard,
  cellSpacing: 16.0,
  oxygenIdleDrain: 2.1,
  oxygenThrottleDrain: 3.6,
);

const Level level8 = Level(
  number: 8,
  name: 'Hollow Moor',
  subtitle: 'Dead ground under a full moon. Long blind crests where you '
      'cannot see the landing until you are already committed to it.',
  length: 1300,
  seed: 1031977,
  amplitude: 4.30,
  wavelength: 34.0,
  macroScale: 3.2,
  macroWavelengthFactor: 9.5,
  slopeBudget: 0.84,
  theme: moonlitMoor,
  cellSpacing: 20.0,
  oxygenIdleDrain: 1.9,
  oxygenThrottleDrain: 3.5,
);

const Level level9 = Level(
  number: 9,
  name: 'Floodlit Coliseum',
  subtitle: 'A built course, and it shows: every ramp is deliberate and '
      'every one of them is aimed at putting you on your roof.',
  length: 1400,
  seed: 5590231,
  amplitude: 4.20,
  wavelength: 13.5,
  macroScale: 2.8,
  macroWavelengthFactor: 6.5,
  slopeBudget: 0.93,
  theme: floodlitArena,
  cellSpacing: 15.0,
  oxygenIdleDrain: 2.0,
  oxygenThrottleDrain: 3.8,
);

const Level level10 = Level(
  number: 10,
  name: 'Sunbaked Mesa',
  subtitle: 'The last one. Canyon walls of baked sandstone, no shade, and '
      'a climb that does not let up until the line.',
  length: 1500,
  seed: 7770419,
  amplitude: 3.60,
  wavelength: 21.0,
  macroScale: 4.0,
  macroWavelengthFactor: 8.0,
  slopeBudget: 0.94,
  theme: sunbakedMesa,
  cellSpacing: 17.0,
  oxygenIdleDrain: 2.2,
  oxygenThrottleDrain: 4.0,
);

/// Every level, in play order.
const List<Level> levels = [
  level1,
  level2,
  level3,
  level4,
  level5,
  level6,
  level7,
  level8,
  level9,
  level10,
];

/// The next course after [level], or null if it is the last one.
Level? levelAfter(Level level) {
  final i = levels.indexWhere((l) => l.number == level.number);
  if (i < 0 || i + 1 >= levels.length) return null;
  return levels[i + 1];
}

import 'package:flame/components.dart';

import '../config.dart';

/// Where one wheel sits on a machine, and how it behaves.
///
/// A machine carries a list of these rather than a fixed front/rear pair,
/// so a bike, a trike and a six-wheeler are all the same code.
class WheelMount {
  const WheelMount({
    required this.anchor,
    required this.radius,
    this.driven = true,
    this.spriteScale = 1.088,
  });

  /// Position in chassis-local metres, measured off the art.
  final Vector2 anchor;

  final double radius;

  /// Whether the engine drives this wheel.
  final bool driven;

  /// Drawn diameter is radius * 2 * this. The tyre art fills about 92% of
  /// its square canvas, hence the default just over 1.
  final double spriteScale;
}

/// One drivable machine.
///
/// Mirrors [Level]: everything that makes a vehicle feel different lives
/// here as data, so adding one is a declaration plus two PNGs, with no
/// changes to the physics or rendering code. (Not const, only because
/// Vector2 cannot be.)
///
/// GameConfig still holds the values that are the same for every vehicle
/// (gravity, camera, terrain); anything a vehicle can differ on moved here.
class Vehicle {
  Vehicle({
    required this.id,
    required this.name,
    required this.tagline,
    required this.bodyAsset,
    required this.wheelAsset,
    required this.spriteSize,
    required this.chassisSize,
    required this.wheels,
    required this.driverOffset,
    required this.headOffset,
    required this.engineMaxTorque,
    required this.engineMaxMotorSpeed,
    required this.wheelFriction,
    required this.suspensionFrequencyHz,
    required this.suspensionDampingRatio,
    required this.chassisDensity,
    required this.wheelDensity,
    required this.headDensity,
    required this.chassisPitchTorque,
    Vector2? spriteOffset,
    this.driverAsset = 'character.png',
    this.driverBehind = false,
    this.driverScale = 1.0,
    this.headRadius = 0.31,
    this.wheelAngularDamping = GameConfig.wheelAngularDamping,
    this.powerCurveExponent = 2.0,
    this.dragCoefficient = 0.9,
  }) : spriteOffset = spriteOffset ?? Vector2.zero();

  // --- identity -------------------------------------------------------
  final String id;
  final String name;
  final String tagline;

  /// File names under assets/images/.
  final String bodyAsset;
  final String wheelAsset;

  // --- geometry (metres) ----------------------------------------------

  /// Drawn size of the chassis art. All the body sprites are 3:2, so this
  /// is effectively "how long is this machine".
  final Vector2 spriteSize;

  /// Nudge of the art relative to the physics box centre.
  final Vector2 spriteOffset;

  /// Collision box for the chassis.
  final Vector2 chassisSize;

  /// Every wheel on the machine, in any order. Two for a bike, three for
  /// a trike, six for a hauler - the physics and the garage both just
  /// iterate.
  final List<WheelMount> wheels;

  // --- driver ---------------------------------------------------------

  /// Which driver art this machine carries.
  ///
  /// `character.png` is a seated driver holding a steering wheel, which
  /// only reads right in a cab. Bikes and trikes use `rider.png` - the
  /// same character with the bucket seat and the wheel cut away, so his
  /// fists close on handlebars instead.
  final String driverAsset;

  /// Whether the driver is drawn behind the chassis art.
  ///
  /// In a cab he belongs in front. On a bike he belongs behind: the art is
  /// a seated pose with the legs thrown forward, which is exactly what a
  /// tank and a fairing hide. Behind the body, all that shows is helmet,
  /// shoulders and the arms out to the bars - which is what a rider looks
  /// like from the side anyway.
  final bool driverBehind;

  /// The driver sprite scales and is placed per vehicle.
  final double driverScale;
  final Vector2 driverOffset;

  /// The helmet body - the flip detector. Sitting high, its mass is what
  /// makes a machine top-heavy.
  final double headRadius;
  final Vector2 headOffset;
  final double headDensity;

  // --- handling -------------------------------------------------------
  final double chassisDensity;
  final double wheelDensity;

  /// GRIP. The single biggest handling difference between machines.
  final double wheelFriction;
  final double wheelAngularDamping;

  final double suspensionFrequencyHz;
  final double suspensionDampingRatio;

  final double engineMaxTorque;
  final double engineMaxMotorSpeed;

  /// Nose-lift under throttle - the wheelie.
  final double chassisPitchTorque;

  /// Shape of the torque fall-off as the wheels spin up.
  ///
  /// The motor is a speed servo, so with a flat torque limit the machine
  /// holds its target speed up any slope it can grip - hills stop mattering
  /// and the game plays itself. Real engines have far less to give at high
  /// rpm, so available torque falls from full at a standstill to nothing at
  /// the speed cap:
  ///
  ///   torque = engineMaxTorque * (1 - (spin / maxSpin)^exponent)
  ///
  /// 1.0 is a linear fade, 2.0 keeps low-end grunt and drops off sharply
  /// near the top, 3.0+ feels like a big lazy engine.
  final double powerCurveExponent;

  /// Quadratic drag on the chassis, in N per (m/s)^2.
  ///
  /// This is what actually sets the top speed on the flat: the machine
  /// accelerates until available torque equals drag. Without it the servo
  /// would simply snap to its setpoint.
  final double dragCoefficient;

  Vector2 get driverSize => Vector2(1.38, 1.41) * driverScale;

  int get wheelCount => wheels.length;

  /// Frontmost and rearmost wheels, used for the wheelbase readout and to
  /// place the machine on the ground at spawn.
  WheelMount get rearmost =>
      wheels.reduce((a, b) => a.anchor.x <= b.anchor.x ? a : b);
  WheelMount get frontmost =>
      wheels.reduce((a, b) => a.anchor.x >= b.anchor.x ? a : b);

  double get wheelbase => frontmost.anchor.x - rearmost.anchor.x;

  /// Deepest point any wheel reaches below the chassis centre - what the
  /// spawn height has to clear.
  double get lowestWheelExtent => wheels
      .map((w) => w.anchor.y + w.radius)
      .reduce((a, b) => a > b ? a : b);

  /// Representative radius for the speed readout.
  double get driveRadius {
    final driven = wheels.where((w) => w.driven);
    final set = driven.isEmpty ? wheels : driven;
    return set.map((w) => w.radius).reduce((a, b) => a + b) / set.length;
  }

  /// Rough top speed in m/s, for the garage readout.
  ///
  /// These were originally set for ~24 m/s (88 km/h), which let any
  /// machine simply rocket over the terrain and made every course feel
  /// flat. A hill-climb wants 7-15 m/s so the hills actually push back.
  double get topSpeed => engineMaxMotorSpeed * driveRadius;

  double get topSpeedKmh => topSpeed * 3.6;
}

/// Where the fists sit on each driver sprite, as a fraction of its canvas.
///
/// This is the single number every driver placement is fitted against: a
/// machine's `driverOffset` is chosen so that this point lands on that
/// machine's handlebar grip or steering column. test/driver_fit_test.dart
/// then checks the result against the real art, so a driver can no longer
/// end up sitting in mid-air without CI saying so.
final Map<String, Vector2> driverHandAnchor = {
  'character.png': Vector2(0.652, 0.474),
  'rider.png': Vector2(0.730, 0.430),
  'driver.png': Vector2(0.670, 0.470),
};

/// -------------------------------------------------------------------
/// THE GARAGE
///
/// Geometry was measured off each piece of art by compositing the wheels
/// onto the chassis, so the wheels sit in their arches without tuning.
/// Handling is deliberately spread out: no machine is best everywhere.
/// -------------------------------------------------------------------

/// The starter. Middling everything - the yardstick the others are read
/// against.
final Vehicle rover = Vehicle(
  id: 'rover',
  name: 'Pathfinder',
  tagline: 'The one you learn on. No weakness, no speciality.',
  bodyAsset: 'car_body.png',
  wheelAsset: 'wheel.png',
  spriteSize: Vector2(4.6, 3.07),
  spriteOffset: Vector2(0, -0.15),
  chassisSize: Vector2(3.4, 1.05),
  wheels: [
    WheelMount(anchor: Vector2(-1.05, 0.69), radius: 0.58),
    WheelMount(anchor: Vector2(1.46, 0.69), radius: 0.58),
  ],
  driverOffset: Vector2(0.10, -0.40),
  headOffset: Vector2(-0.14, -0.82),
  chassisDensity: 1.0,
  wheelDensity: 1.1,
  headDensity: 0.6,
  wheelFriction: 2.1,
  suspensionFrequencyHz: 5.0,
  suspensionDampingRatio: 0.65,
  engineMaxTorque: 62,
  engineMaxMotorSpeed: 19,
  chassisPitchTorque: 34,
  powerCurveExponent: 2.0,
  dragCoefficient: 0.9,
);

/// Light and quick, but it skates on loose ground and has little torque
/// for a steep face.
final Vehicle scout = Vehicle(
  id: 'scout',
  name: 'Skimmer',
  tagline: 'Feather-light and fast. Slips on anything steep.',
  bodyAsset: 'scout_body.png',
  wheelAsset: 'scout_wheel.png',
  spriteSize: Vector2(4.3, 2.87),
  chassisSize: Vector2(3.0, 0.85),
  wheels: [
    WheelMount(anchor: Vector2(-1.31, 0.63), radius: 0.49),
    WheelMount(anchor: Vector2(1.33, 0.63), radius: 0.49),
  ],
  driverOffset: Vector2(-0.30, -0.30),
  headOffset: Vector2(-0.44, -0.74),
  driverScale: 0.92,
  headRadius: 0.28,
  chassisDensity: 0.62,
  wheelDensity: 0.75,
  headDensity: 0.7,
  wheelFriction: 1.3,
  suspensionFrequencyHz: 6.4,
  suspensionDampingRatio: 0.55,
  engineMaxTorque: 40,
  engineMaxMotorSpeed: 29,
  chassisPitchTorque: 26,
  // Peaky and light: revs out fast, little low-end shove.
  powerCurveExponent: 1.3,
  dragCoefficient: 0.55,
);

/// Enormous torque and grip, but heavy and slow. Climbs anything.
final Vehicle hauler = Vehicle(
  id: 'hauler',
  name: 'Ox',
  tagline: 'Slow, immensely heavy, and it will climb absolutely anything.',
  bodyAsset: 'hauler_body.png',
  wheelAsset: 'hauler_wheel.png',
  spriteSize: Vector2(5.4, 3.6),
  chassisSize: Vector2(4.0, 1.35),
  wheels: [
    WheelMount(anchor: Vector2(-1.57, 0.65), radius: 0.745, spriteScale: 1.087),
    WheelMount(anchor: Vector2(1.35, 0.65), radius: 0.745, spriteScale: 1.087),
  ],
  driverOffset: Vector2(0.62, -0.62),
  headOffset: Vector2(0.48, -1.06),
  driverScale: 1.0,
  chassisDensity: 2.1,
  wheelDensity: 1.6,
  headDensity: 0.45,
  wheelFriction: 2.9,
  suspensionFrequencyHz: 4.2,
  suspensionDampingRatio: 0.8,
  engineMaxTorque: 128,
  engineMaxMotorSpeed: 10,
  chassisPitchTorque: 20,
  // A big lazy diesel: enormous grunt that holds almost to the cap.
  powerCurveExponent: 3.2,
  dragCoefficient: 2.4,
);

/// Huge suspension travel and a soft spring. Built to land from height.
final Vehicle jumper = Vehicle(
  id: 'jumper',
  name: 'Leaper',
  tagline: 'Enormous travel. Lands from anything, twitchy on the ground.',
  bodyAsset: 'jumper_body.png',
  wheelAsset: 'jumper_wheel.png',
  spriteSize: Vector2(5.0, 3.33),
  chassisSize: Vector2(3.5, 1.0),
  wheels: [
    WheelMount(anchor: Vector2(-1.67, 0.76), radius: 0.598),
    WheelMount(anchor: Vector2(1.73, 0.76), radius: 0.598),
  ],
  driverOffset: Vector2(-0.28, -0.48),
  headOffset: Vector2(-0.42, -0.92),
  chassisDensity: 0.95,
  wheelDensity: 1.0,
  headDensity: 0.62,
  wheelFriction: 2.0,
  // Soft and slow to rebound - that is the whole point of this machine.
  suspensionFrequencyHz: 3.1,
  suspensionDampingRatio: 0.42,
  engineMaxTorque: 70,
  engineMaxMotorSpeed: 20,
  chassisPitchTorque: 44,
  powerCurveExponent: 1.8,
  dragCoefficient: 1.0,
);

/// Long wheelbase, low centre of gravity, very hard to flip - but the
/// length makes it clumsy over short, sharp ridges.
final Vehicle crawler = Vehicle(
  id: 'crawler',
  name: 'Anchor',
  tagline: 'Long and low. Almost impossible to flip, clumsy over ripples.',
  bodyAsset: 'crawler_body.png',
  wheelAsset: 'crawler_wheel.png',
  spriteSize: Vector2(5.6, 3.73),
  chassisSize: Vector2(4.2, 1.0),
  wheels: [
    WheelMount(anchor: Vector2(-2.02, 0.65), radius: 0.592),
    WheelMount(anchor: Vector2(2.14, 0.65), radius: 0.592),
  ],
  driverOffset: Vector2(-0.32, -0.40),
  headOffset: Vector2(-0.46, -0.84),
  chassisDensity: 1.5,
  wheelDensity: 1.3,
  // Light helmet mass and a long wheelbase: this is the stable one.
  headDensity: 0.25,
  wheelFriction: 2.7,
  suspensionFrequencyHz: 5.6,
  suspensionDampingRatio: 0.78,
  engineMaxTorque: 96,
  engineMaxMotorSpeed: 14,
  chassisPitchTorque: 16,
  powerCurveExponent: 2.8,
  dragCoefficient: 1.7,
);



/// -------------------------------------------------------------------
/// TWO-WHEELERS
///
/// Light, quick and tippy: a tall helmet mass on a short wheelbase is
/// what makes a bike interesting to ride and easy to loop.
/// -------------------------------------------------------------------

final Vehicle dustdevil = Vehicle(
  id: 'dustdevil',
  name: 'Dust Devil',
  tagline: 'Flickable trials bike. Points anywhere, holds nothing.',
  bodyAsset: 'dustdevil_body.png',
  wheelAsset: 'dustdevil_wheel.png',
  spriteSize: Vector2(3.2, 2.13),
  chassisSize: Vector2(2.2, 0.55),
  wheels: [
    WheelMount(anchor: Vector2(-1.09, 0.62), radius: 0.44, spriteScale: 1.09),
    WheelMount(anchor: Vector2(1.06, 0.62), radius: 0.44, spriteScale: 1.09),
  ],
  driverAsset: 'rider.png',
  driverScale: 1.3,
  driverOffset: Vector2(-0.09, -0.49),
  headOffset: Vector2(0.03, -1.13),
  headRadius: 0.33,
  chassisDensity: 0.5,
  wheelDensity: 0.9,
  headDensity: 0.75,
  wheelFriction: 2.0,
  suspensionFrequencyHz: 5.8,
  suspensionDampingRatio: 0.6,
  engineMaxTorque: 45,
  engineMaxMotorSpeed: 26,
  chassisPitchTorque: 20,
  powerCurveExponent: 2.0,
  dragCoefficient: 0.62,
);

final Vehicle piston = Vehicle(
  id: 'piston',
  name: 'Piston',
  tagline: 'Absurd shove off the line, and a swingarm you can land on.',
  bodyAsset: 'piston_body.png',
  wheelAsset: 'piston_wheel.png',
  spriteSize: Vector2(3.2, 2.13),
  chassisSize: Vector2(2.2, 0.55),
  wheels: [
    WheelMount(anchor: Vector2(-1.44, 0.48), radius: 0.44, spriteScale: 1.09),
    WheelMount(anchor: Vector2(1.38, 0.48), radius: 0.44, spriteScale: 1.09),
  ],
  driverAsset: 'rider.png',
  driverScale: 1.3,
  driverOffset: Vector2(0.42, -0.36),
  headOffset: Vector2(0.54, -1.00),
  headRadius: 0.33,
  chassisDensity: 0.7,
  wheelDensity: 0.9,
  headDensity: 0.8,
  wheelFriction: 1.7,
  suspensionFrequencyHz: 6.5,
  suspensionDampingRatio: 0.5,
  engineMaxTorque: 96,
  engineMaxMotorSpeed: 30,
  chassisPitchTorque: 43,
  powerCurveExponent: 1.5,
  dragCoefficient: 0.6,
);

final Vehicle gecko = Vehicle(
  id: 'gecko',
  name: 'Gecko',
  tagline: 'Short, grippy and stubborn. Walks up things it should not.',
  bodyAsset: 'gecko_body.png',
  wheelAsset: 'gecko_wheel.png',
  spriteSize: Vector2(3.2, 2.13),
  chassisSize: Vector2(2.2, 0.55),
  wheels: [
    WheelMount(anchor: Vector2(-1.15, 0.59), radius: 0.44, spriteScale: 1.09),
    WheelMount(anchor: Vector2(1.06, 0.59), radius: 0.44, spriteScale: 1.09),
  ],
  driverAsset: 'rider.png',
  driverScale: 1.3,
  driverOffset: Vector2(-0.08, -0.53),
  headOffset: Vector2(0.04, -1.17),
  headRadius: 0.33,
  chassisDensity: 0.55,
  wheelDensity: 0.9,
  headDensity: 0.7,
  wheelFriction: 2.8,
  suspensionFrequencyHz: 5.2,
  suspensionDampingRatio: 0.7,
  engineMaxTorque: 62,
  engineMaxMotorSpeed: 20,
  chassisPitchTorque: 28,
  powerCurveExponent: 2.4,
  dragCoefficient: 0.7,
);

final Vehicle ionwing = Vehicle(
  id: 'ionwing',
  name: 'Ionwing',
  tagline: 'Barely there. Thruster-light, and slides on a bad look.',
  bodyAsset: 'ionwing_body.png',
  wheelAsset: 'ionwing_wheel.png',
  spriteSize: Vector2(3.2, 2.13),
  chassisSize: Vector2(2.2, 0.55),
  wheels: [
    WheelMount(anchor: Vector2(-1.12, 0.50), radius: 0.44, spriteScale: 1.09),
    WheelMount(anchor: Vector2(1.06, 0.50), radius: 0.44, spriteScale: 1.09),
  ],
  driverAsset: 'rider.png',
  driverScale: 1.3,
  driverOffset: Vector2(0.07, -0.47),
  headOffset: Vector2(0.19, -1.11),
  headRadius: 0.33,
  chassisDensity: 0.42,
  wheelDensity: 0.9,
  headDensity: 0.65,
  wheelFriction: 1.6,
  suspensionFrequencyHz: 4.2,
  suspensionDampingRatio: 0.45,
  engineMaxTorque: 40,
  engineMaxMotorSpeed: 32,
  chassisPitchTorque: 18,
  powerCurveExponent: 1.6,
  dragCoefficient: 0.48,
);

final Vehicle scarab = Vehicle(
  id: 'scarab',
  name: 'Scarab',
  tagline: 'Fat tyres for soft ground. Unhurried and sure-footed.',
  bodyAsset: 'scarab_body.png',
  wheelAsset: 'scarab_wheel.png',
  spriteSize: Vector2(3.2, 2.13),
  chassisSize: Vector2(2.2, 0.55),
  wheels: [
    WheelMount(anchor: Vector2(-1.39, 0.53), radius: 0.44, spriteScale: 1.09),
    WheelMount(anchor: Vector2(1.12, 0.53), radius: 0.44, spriteScale: 1.09),
  ],
  driverAsset: 'rider.png',
  driverScale: 1.3,
  driverOffset: Vector2(-0.09, -0.49),
  headOffset: Vector2(0.03, -1.13),
  headRadius: 0.33,
  chassisDensity: 0.62,
  wheelDensity: 0.9,
  headDensity: 0.7,
  wheelFriction: 2.5,
  suspensionFrequencyHz: 4.6,
  suspensionDampingRatio: 0.62,
  engineMaxTorque: 58,
  engineMaxMotorSpeed: 22,
  chassisPitchTorque: 26,
  powerCurveExponent: 2.2,
  dragCoefficient: 0.72,
);

final Vehicle needle = Vehicle(
  id: 'needle',
  name: 'Needle',
  tagline: 'Built for one number. Everything else was negotiable.',
  bodyAsset: 'needle_body.png',
  wheelAsset: 'needle_wheel.png',
  spriteSize: Vector2(3.2, 2.13),
  chassisSize: Vector2(2.2, 0.55),
  wheels: [
    WheelMount(anchor: Vector2(-1.44, 0.42), radius: 0.44, spriteScale: 1.09),
    WheelMount(anchor: Vector2(1.12, 0.42), radius: 0.44, spriteScale: 1.09),
  ],
  driverAsset: 'rider.png',
  driverScale: 1.3,
  driverOffset: Vector2(0.58, -0.34),
  headOffset: Vector2(0.70, -0.98),
  headRadius: 0.33,
  chassisDensity: 0.6,
  wheelDensity: 0.9,
  headDensity: 0.85,
  wheelFriction: 1.5,
  suspensionFrequencyHz: 7.5,
  suspensionDampingRatio: 0.55,
  engineMaxTorque: 44,
  engineMaxMotorSpeed: 38,
  chassisPitchTorque: 20,
  powerCurveExponent: 1.2,
  dragCoefficient: 0.4,
);

final Vehicle ratchet = Vehicle(
  id: 'ratchet',
  name: 'Ratchet',
  tagline: 'Someone welded this out of three other bikes. It runs.',
  bodyAsset: 'ratchet_body.png',
  wheelAsset: 'ratchet_wheel.png',
  spriteSize: Vector2(3.2, 2.13),
  chassisSize: Vector2(2.2, 0.55),
  wheels: [
    WheelMount(anchor: Vector2(-1.44, 0.53), radius: 0.44, spriteScale: 1.09),
    WheelMount(anchor: Vector2(1.12, 0.53), radius: 0.44, spriteScale: 1.09),
  ],
  driverAsset: 'rider.png',
  driverScale: 1.3,
  driverOffset: Vector2(0.07, -0.49),
  headOffset: Vector2(0.19, -1.13),
  headRadius: 0.33,
  chassisDensity: 0.58,
  wheelDensity: 0.9,
  headDensity: 0.8,
  wheelFriction: 1.9,
  suspensionFrequencyHz: 5.0,
  suspensionDampingRatio: 0.55,
  engineMaxTorque: 50,
  engineMaxMotorSpeed: 21,
  chassisPitchTorque: 22,
  powerCurveExponent: 2.1,
  dragCoefficient: 0.68,
);


/// -------------------------------------------------------------------
/// TRIKES
///
/// In side view a reverse trike's two front wheels sit at the same x, so
/// these are two-axle machines here. The third wheel is width, not
/// length - it shows up as grip and stability, not as another mount.
/// -------------------------------------------------------------------

final Vehicle trilobite = Vehicle(
  id: 'trilobite',
  name: 'Trilobite',
  tagline: 'Two wheels up front and a low armoured nose. Planted.',
  bodyAsset: 'trilobite_body.png',
  wheelAsset: 'trilobite_wheel.png',
  spriteSize: Vector2(4.4, 2.93),
  chassisSize: Vector2(3.2, 0.8),
  wheels: [
    WheelMount(anchor: Vector2(-1.98, 0.50), radius: 0.49, spriteScale: 1.09),
    WheelMount(anchor: Vector2(0.79, 0.50), radius: 0.49, spriteScale: 1.09),
  ],
  driverAsset: 'driver.png',
  driverBehind: true,
  driverScale: 1.05,
  driverOffset: Vector2(-0.12, -0.52),
  headOffset: Vector2(-0.41, -0.96),
  headRadius: 0.27,
  chassisDensity: 1.1,
  wheelDensity: 0.9,
  headDensity: 0.4,
  wheelFriction: 2.6,
  suspensionFrequencyHz: 5.4,
  suspensionDampingRatio: 0.7,
  engineMaxTorque: 78,
  engineMaxMotorSpeed: 20,
  chassisPitchTorque: 35,
  powerCurveExponent: 2.2,
  dragCoefficient: 1.1,
);

final Vehicle wasp = Vehicle(
  id: 'wasp',
  name: 'Wasp',
  tagline: 'Sharp and light. Rewards a clean line, punishes a lazy one.',
  bodyAsset: 'wasp_body.png',
  wheelAsset: 'wasp_wheel.png',
  spriteSize: Vector2(4.4, 2.93),
  chassisSize: Vector2(3.2, 0.8),
  wheels: [
    WheelMount(anchor: Vector2(-1.72, 0.45), radius: 0.49, spriteScale: 1.09),
    WheelMount(anchor: Vector2(1.36, 0.45), radius: 0.49, spriteScale: 1.09),
  ],
  driverAsset: 'driver.png',
  driverBehind: true,
  driverScale: 1.05,
  driverOffset: Vector2(-0.21, -0.46),
  headOffset: Vector2(-0.50, -0.90),
  headRadius: 0.27,
  chassisDensity: 0.8,
  wheelDensity: 0.9,
  headDensity: 0.6,
  wheelFriction: 1.9,
  suspensionFrequencyHz: 6.0,
  suspensionDampingRatio: 0.55,
  engineMaxTorque: 58,
  engineMaxMotorSpeed: 30,
  chassisPitchTorque: 26,
  powerCurveExponent: 1.6,
  dragCoefficient: 0.75,
);

final Vehicle kite = Vehicle(
  id: 'kite',
  name: 'Kite',
  tagline: 'Solar-fed and slow, but it never seems to run out.',
  bodyAsset: 'kite_body.png',
  wheelAsset: 'kite_wheel.png',
  spriteSize: Vector2(4.4, 2.93),
  chassisSize: Vector2(3.2, 0.8),
  wheels: [
    WheelMount(anchor: Vector2(-1.94, 0.35), radius: 0.49, spriteScale: 1.09),
    WheelMount(anchor: Vector2(1.54, 0.35), radius: 0.49, spriteScale: 1.09),
  ],
  driverAsset: 'driver.png',
  driverBehind: true,
  driverScale: 1.05,
  driverOffset: Vector2(-0.16, -0.37),
  headOffset: Vector2(-0.45, -0.81),
  headRadius: 0.27,
  chassisDensity: 0.9,
  wheelDensity: 0.9,
  headDensity: 0.5,
  wheelFriction: 2.4,
  suspensionFrequencyHz: 5.0,
  suspensionDampingRatio: 0.66,
  engineMaxTorque: 52,
  engineMaxMotorSpeed: 16,
  chassisPitchTorque: 23,
  powerCurveExponent: 2.6,
  dragCoefficient: 1.6,
);

final Vehicle haulertrike = Vehicle(
  id: 'haulertrike',
  name: 'Hauler Trike',
  tagline: 'Loaded to the roll bar. Slow, heavy, and it does not care.',
  bodyAsset: 'haulertrike_body.png',
  wheelAsset: 'haulertrike_wheel.png',
  spriteSize: Vector2(4.4, 2.93),
  chassisSize: Vector2(3.2, 0.8),
  wheels: [
    WheelMount(anchor: Vector2(-1.76, 0.45), radius: 0.49, spriteScale: 1.09),
    WheelMount(anchor: Vector2(1.58, 0.45), radius: 0.49, spriteScale: 1.09),
  ],
  driverAsset: 'driver.png',
  driverBehind: true,
  driverScale: 1.05,
  driverOffset: Vector2(-0.03, -0.46),
  headOffset: Vector2(-0.32, -0.90),
  headRadius: 0.27,
  chassisDensity: 1.7,
  wheelDensity: 0.9,
  headDensity: 0.35,
  wheelFriction: 2.9,
  suspensionFrequencyHz: 4.4,
  suspensionDampingRatio: 0.78,
  engineMaxTorque: 104,
  engineMaxMotorSpeed: 14,
  chassisPitchTorque: 47,
  powerCurveExponent: 3.0,
  dragCoefficient: 2.0,
);

final Vehicle compass = Vehicle(
  id: 'compass',
  name: 'Compass',
  tagline: 'Instruments everywhere. Steady, deliberate, well behaved.',
  bodyAsset: 'compass_body.png',
  wheelAsset: 'compass_wheel.png',
  spriteSize: Vector2(4.4, 2.93),
  chassisSize: Vector2(3.2, 0.8),
  wheels: [
    WheelMount(anchor: Vector2(-1.76, 0.42), radius: 0.49, spriteScale: 1.09),
    WheelMount(anchor: Vector2(1.06, 0.42), radius: 0.49, spriteScale: 1.09),
  ],
  driverAsset: 'driver.png',
  driverBehind: true,
  driverScale: 1.05,
  driverOffset: Vector2(-0.08, -0.40),
  headOffset: Vector2(-0.37, -0.84),
  headRadius: 0.27,
  chassisDensity: 1.0,
  wheelDensity: 0.9,
  headDensity: 0.45,
  wheelFriction: 2.5,
  suspensionFrequencyHz: 5.2,
  suspensionDampingRatio: 0.72,
  engineMaxTorque: 68,
  engineMaxMotorSpeed: 19,
  chassisPitchTorque: 31,
  powerCurveExponent: 2.4,
  dragCoefficient: 1.2,
);

final Vehicle cinder = Vehicle(
  id: 'cinder',
  name: 'Cinder',
  tagline: 'A hot rod that wants the throttle open and the nose up.',
  bodyAsset: 'cinder_body.png',
  wheelAsset: 'cinder_wheel.png',
  spriteSize: Vector2(4.4, 2.93),
  chassisSize: Vector2(3.2, 0.8),
  wheels: [
    WheelMount(anchor: Vector2(-1.89, 0.44), radius: 0.49, spriteScale: 1.09),
    WheelMount(anchor: Vector2(1.14, 0.44), radius: 0.49, spriteScale: 1.09),
  ],
  driverAsset: 'driver.png',
  driverBehind: true,
  driverScale: 1.05,
  driverOffset: Vector2(-0.21, -0.40),
  headOffset: Vector2(-0.50, -0.84),
  headRadius: 0.27,
  chassisDensity: 0.95,
  wheelDensity: 0.9,
  headDensity: 0.6,
  wheelFriction: 2.0,
  suspensionFrequencyHz: 5.6,
  suspensionDampingRatio: 0.52,
  engineMaxTorque: 92,
  engineMaxMotorSpeed: 26,
  chassisPitchTorque: 41,
  powerCurveExponent: 1.5,
  dragCoefficient: 0.9,
);

final Vehicle stilt = Vehicle(
  id: 'stilt',
  name: 'Stilt',
  tagline: 'All ground clearance and no sense. Tall enough to worry.',
  bodyAsset: 'stilt_body.png',
  wheelAsset: 'stilt_wheel.png',
  spriteSize: Vector2(4.4, 2.93),
  chassisSize: Vector2(3.2, 0.8),
  wheels: [
    WheelMount(anchor: Vector2(-1.98, 0.64), radius: 0.49, spriteScale: 1.09),
    WheelMount(anchor: Vector2(1.32, 0.64), radius: 0.49, spriteScale: 1.09),
  ],
  driverAsset: 'driver.png',
  driverBehind: true,
  driverScale: 1.05,
  driverOffset: Vector2(-0.21, -0.43),
  headOffset: Vector2(-0.50, -0.87),
  headRadius: 0.27,
  chassisDensity: 0.85,
  wheelDensity: 0.9,
  headDensity: 0.9,
  wheelFriction: 2.3,
  suspensionFrequencyHz: 4.8,
  suspensionDampingRatio: 0.6,
  engineMaxTorque: 70,
  engineMaxMotorSpeed: 22,
  chassisPitchTorque: 32,
  powerCurveExponent: 2.2,
  dragCoefficient: 0.95,
);


/// Every vehicle, in garage order: the original rovers, then the bikes,
/// then the trikes.
final List<Vehicle> vehicles = [
  rover, scout, hauler, jumper, crawler,
  dustdevil, piston, gecko, ionwing, scarab, needle, ratchet,
  trilobite, wasp, kite, haulertrike, compass, cinder, stilt,
];

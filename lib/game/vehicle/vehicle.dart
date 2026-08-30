import 'package:flame/components.dart';

import '../config.dart';

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
    required this.wheelRadius,
    required this.rearAnchor,
    required this.frontAnchor,
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
    this.driverScale = 1.0,
    this.headRadius = 0.31,
    this.wheelSpriteScale = 1.088,
    this.wheelAngularDamping = GameConfig.wheelAngularDamping,
    this.rearWheelDrive = true,
    this.frontWheelDrive = true,
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

  final double wheelRadius;

  /// Drawn wheel diameter is wheelRadius * 2 * this. The tyre art fills
  /// about 92% of its square canvas, hence the default just over 1.
  final double wheelSpriteScale;

  /// Wheel positions in chassis-local space, measured off the art.
  final Vector2 rearAnchor;
  final Vector2 frontAnchor;

  // --- driver ---------------------------------------------------------

  /// The driver sprite is shared; this scales and places it per vehicle.
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

  final bool rearWheelDrive;
  final bool frontWheelDrive;

  Vector2 get driverSize => Vector2(1.38, 1.41) * driverScale;

  /// Rough top speed in m/s, for the garage readout.
  double get topSpeed => engineMaxMotorSpeed * wheelRadius;
}

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
  wheelRadius: 0.58,
  rearAnchor: Vector2(-1.05, 0.69),
  frontAnchor: Vector2(1.46, 0.69),
  driverOffset: Vector2(0.10, -0.40),
  headOffset: Vector2(-0.14, -0.82),
  chassisDensity: 1.0,
  wheelDensity: 1.1,
  headDensity: 0.6,
  wheelFriction: 2.4,
  suspensionFrequencyHz: 5.0,
  suspensionDampingRatio: 0.65,
  engineMaxTorque: 62,
  engineMaxMotorSpeed: 42,
  chassisPitchTorque: 34,
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
  wheelRadius: 0.49,
  rearAnchor: Vector2(-1.31, 0.63),
  frontAnchor: Vector2(1.33, 0.63),
  driverOffset: Vector2(-0.30, -0.30),
  headOffset: Vector2(-0.44, -0.74),
  driverScale: 0.92,
  headRadius: 0.28,
  chassisDensity: 0.62,
  wheelDensity: 0.75,
  headDensity: 0.7,
  wheelFriction: 1.5,
  suspensionFrequencyHz: 6.4,
  suspensionDampingRatio: 0.55,
  engineMaxTorque: 40,
  engineMaxMotorSpeed: 62,
  chassisPitchTorque: 26,
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
  wheelRadius: 0.745,
  wheelSpriteScale: 1.087,
  rearAnchor: Vector2(-1.57, 0.65),
  frontAnchor: Vector2(1.35, 0.65),
  driverOffset: Vector2(0.62, -0.62),
  headOffset: Vector2(0.48, -1.06),
  driverScale: 1.0,
  chassisDensity: 2.1,
  wheelDensity: 1.6,
  headDensity: 0.45,
  wheelFriction: 3.1,
  suspensionFrequencyHz: 4.2,
  suspensionDampingRatio: 0.8,
  engineMaxTorque: 128,
  engineMaxMotorSpeed: 26,
  chassisPitchTorque: 20,
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
  wheelRadius: 0.598,
  rearAnchor: Vector2(-1.67, 0.76),
  frontAnchor: Vector2(1.73, 0.76),
  driverOffset: Vector2(-0.28, -0.48),
  headOffset: Vector2(-0.42, -0.92),
  chassisDensity: 0.95,
  wheelDensity: 1.0,
  headDensity: 0.62,
  wheelFriction: 2.2,
  // Soft and slow to rebound - that is the whole point of this machine.
  suspensionFrequencyHz: 3.1,
  suspensionDampingRatio: 0.42,
  engineMaxTorque: 70,
  engineMaxMotorSpeed: 48,
  chassisPitchTorque: 44,
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
  wheelRadius: 0.592,
  rearAnchor: Vector2(-2.02, 0.65),
  frontAnchor: Vector2(2.14, 0.65),
  driverOffset: Vector2(-0.32, -0.40),
  headOffset: Vector2(-0.46, -0.84),
  chassisDensity: 1.5,
  wheelDensity: 1.3,
  // Light helmet mass and a long wheelbase: this is the stable one.
  headDensity: 0.25,
  wheelFriction: 2.9,
  suspensionFrequencyHz: 5.6,
  suspensionDampingRatio: 0.78,
  engineMaxTorque: 96,
  engineMaxMotorSpeed: 32,
  chassisPitchTorque: 16,
);

/// Every vehicle, in garage order.
final List<Vehicle> vehicles = [rover, scout, hauler, jumper, crawler];

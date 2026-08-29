import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// =====================================================================
/// MARS CLIMB - CENTRAL TUNING FILE
///
/// Everything you are likely to want to fiddle with lives here.
/// Units are METRES and SECONDS (Forge2D world units), not pixels.
/// The world is y-DOWN: smaller y == higher up the screen.
/// =====================================================================
class GameConfig {
  GameConfig._();

  // -------------------------------------------------------------------
  // PLANET / GRAVITY
  // -------------------------------------------------------------------

  /// Earth is 9.81. Mars is 3.71. Real Mars gravity feels *floaty* and
  /// slow for an arcade game, so we cheat upward. Drop it toward 3.7 for
  /// big airtime, push it to 12+ for a grounded, punchy feel.
  static const double gravity = 7.2;

  // -------------------------------------------------------------------
  // CAMERA
  // -------------------------------------------------------------------

  /// Logical resolution the camera renders at (letterboxed on any device).
  static final Vector2 resolution = Vector2(1280, 720);

  /// Pixels per metre. Higher == more zoomed in.
  static const double cameraZoom = 34.0;

  /// How fast the camera catches up to the rover (1/s). Higher == stiffer.
  static const double cameraFollowLerp = 6.0;

  /// Camera looks this far ahead of the rover, in metres.
  static const double cameraLookAhead = 3.0;

  // -------------------------------------------------------------------
  // ROVER - BODY GEOMETRY
  // -------------------------------------------------------------------

  /// Physics box for the chassis (collision), in metres.
  static final Vector2 chassisSize = Vector2(3.4, 1.05);

  /// Visual size of car_body.png. Deliberately larger than the physics
  /// box so the art overhangs the hitbox (source art is 3:2).
  static final Vector2 chassisSpriteSize = Vector2(4.6, 3.07);

  /// Nudge the sprite relative to the physics box centre.
  static final Vector2 chassisSpriteOffset = Vector2(0.0, -0.15);

  static const double chassisDensity = 1.0;
  static const double chassisFriction = 0.35;
  static const double chassisRestitution = 0.05;

  // -------------------------------------------------------------------
  // ROVER - WHEELS
  // -------------------------------------------------------------------

  static const double wheelRadius = 0.62;

  /// Visual diameter multiplier for wheel.png (tyre art has some padding).
  static const double wheelSpriteScale = 2.15;

  /// Wheel anchor points in chassis-local space (x: -rear +front, y: down).
  static final Vector2 rearWheelAnchor = Vector2(-1.42, 0.60);
  static final Vector2 frontWheelAnchor = Vector2(1.52, 0.60);

  static const double wheelDensity = 1.1;

  /// GRIP. This is the single biggest handling knob. 0.6 = slippy sand,
  /// 3.0 = go-kart on tarmac.
  static const double wheelFriction = 2.4;
  static const double wheelRestitution = 0.08;

  /// Rolling resistance: angular damping bleeds off wheel spin when you
  /// let go of the gas. 0 = free-wheels forever.
  static const double wheelAngularDamping = 0.35;

  // -------------------------------------------------------------------
  // SUSPENSION (wheel joints)
  // -------------------------------------------------------------------

  /// Suspension travel along the axis, in metres (+/- from rest).
  static const double suspensionLowerTranslation = -0.32;
  static const double suspensionUpperTranslation = 0.32;

  /// Spring natural frequency in Hz. ~4 Hz = soft buggy, ~9 Hz = stiff.
  static const double suspensionFrequencyHz = 5.0;

  /// 0 = bouncy forever, 1 = critically damped (no bounce).
  static const double suspensionDampingRatio = 0.65;

  /// Suspension axis in chassis-local space. (0,-1) == pushes straight up.
  static final Vector2 suspensionAxis = Vector2(0, -1);

  // -------------------------------------------------------------------
  // ENGINE
  // -------------------------------------------------------------------

  /// Peak torque the wheel motors can deliver (N*m). More == more climb.
  static const double engineMaxTorque = 62.0;

  /// Target wheel spin under full throttle (rad/s). Caps the top speed.
  static const double engineMaxMotorSpeed = 42.0;

  /// Reverse is deliberately weaker than forward.
  static const double reverseTorqueFactor = 0.55;
  static const double reverseMotorSpeedFactor = 0.45;

  /// Braking torque applied when you hold BRAKE while rolling forward.
  static const double brakeTorque = 90.0;

  /// Which wheels get drive torque.
  static const bool rearWheelDrive = true;
  static const bool frontWheelDrive = true; // both true == AWD

  /// Sign convention: in Flame's y-down world, +1 should drive RIGHT.
  /// If your rover reverses into the hills, flip this to -1.
  static const double driveDirection = 1.0;

  /// Extra torque applied to the chassis itself while on the gas, so the
  /// nose lifts under acceleration (the classic hill-climb wheelie).
  static const double chassisPitchTorque = 34.0;

  // -------------------------------------------------------------------
  // DRIVER
  // -------------------------------------------------------------------

  static final Vector2 driverSpriteSize = Vector2(2.35, 2.4);

  /// Where the character art sits relative to the chassis centre.
  static final Vector2 driverSpriteOffset = Vector2(-0.25, -1.15);

  /// The head is a real physics body (welded to the chassis) so we can
  /// detect a face-plant. Position is chassis-local.
  static const double headRadius = 0.36;
  static final Vector2 headOffset = Vector2(-0.72, -1.72);
  static const double headDensity = 0.35;

  // -------------------------------------------------------------------
  // TERRAIN
  // -------------------------------------------------------------------

  /// Horizontal spacing between generated surface points. Smaller ==
  /// smoother terrain but more physics vertices.
  static const double terrainPointSpacing = 0.6;

  /// One chain-shape body covers this many metres.
  static const double terrainChunkWidth = 42.0;

  /// Keep this many chunks generated ahead of / behind the rover.
  static const int terrainChunksAhead = 3;
  static const int terrainChunksBehind = 1;

  /// y of "sea level". Hills rise above (smaller y) and dip below.
  static const double terrainBaseY = 0.0;

  /// How far the solid ground fill extends below the surface line.
  static const double terrainFillDepth = 40.0;

  /// Peak-to-trough hill amplitude, in metres.
  static const double terrainAmplitude = 5.2;

  /// Metres per unit of noise. Bigger == longer, lazier hills.
  static const double terrainWavelength = 26.0;

  /// Layered noise: more octaves == more small bumps on the big hills.
  static const int terrainOctaves = 4;
  static const double terrainPersistence = 0.45;
  static const double terrainLacunarity = 2.1;

  /// The first N metres are flat so the rover can spawn and settle.
  static const double terrainFlatRunway = 22.0;

  /// Amplitude ramps in over this distance after the runway.
  static const double terrainRampDistance = 40.0;

  static const double terrainFriction = 0.92;
  static const double terrainRestitution = 0.0;

  /// Change this for a different world.
  static const int terrainSeed = 20260829;

  // -------------------------------------------------------------------
  // OXYGEN / FUEL CELL
  // -------------------------------------------------------------------

  static const double oxygenMax = 100.0;

  /// Units drained per second just for being alive.
  static const double oxygenIdleDrain = 1.6;

  /// Extra units per second at full throttle.
  static const double oxygenThrottleDrain = 3.4;

  /// Oxygen restored by one energy cell.
  static const double oxygenPerCell = 14.0;

  // -------------------------------------------------------------------
  // COLLECTIBLES (energy cells)
  // -------------------------------------------------------------------

  /// Average metres between cells.
  static const double cellSpacing = 17.0;

  /// How far above the terrain surface a cell floats.
  static const double cellHoverHeight = 1.5;

  static const double cellRadius = 0.45;

  // -------------------------------------------------------------------
  // COLLISION FILTERING
  // -------------------------------------------------------------------

  static const int categoryTerrain = 0x0001;
  static const int categoryVehicle = 0x0002;
  static const int categoryDriver = 0x0004;
  static const int categoryPickup = 0x0008;

  // -------------------------------------------------------------------
  // MARS PALETTE
  // -------------------------------------------------------------------

  static const Color skyTop = Color(0xFF2B1A2E);
  static const Color skyMid = Color(0xFF8A3B2A);
  static const Color skyLow = Color(0xFFD4703C);
  static const Color skyHorizon = Color(0xFFE9A063);

  static const Color mountainFar = Color(0xFF6E3A32);
  static const Color mountainMid = Color(0xFF8A4633);
  static const Color mountainNear = Color(0xFF5E2C22);

  static const Color groundFill = Color(0xFF9C4426);
  static const Color groundFillDeep = Color(0xFF4E1E13);
  static const Color groundCrust = Color(0xFFD8703A);

  static const Color sun = Color(0xFFFFE2B0);
  static const Color accent = Color(0xFFFF8A3D);
  static const Color cellCore = Color(0xFF6FF0D2);
  static const Color cellGlow = Color(0xFF2BB8A0);
}

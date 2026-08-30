import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../config.dart';
import 'driver_head.dart';
import 'vehicle.dart';
import 'wheel.dart';

/// Throttle state driven by the on-screen buttons.
enum Throttle { none, forward, reverse }

/// The player's machine: chassis body + two wheels on spring wheel-joints,
/// with the driver art and a welded head body on top.
///
/// Every dimension and handling number comes from the [Vehicle] it is
/// built from, so this class is the same code for all five machines.
///
/// [Rover] is the chassis BodyComponent itself; the wheels and head are
/// siblings in the physics world (joints can't cross component trees in
/// any meaningful way, so they all get added to the same world).
class Rover extends BodyComponent {
  Rover({
    required this.spawn,
    required this.vehicle,
    required this.chassisSprite,
    required this.wheelSprite,
    required this.driverSprite,
    required this.onHeadImpact,
  }) {
    renderBody = false;
    priority = 10;
  }

  final Vector2 spawn;
  final Vehicle vehicle;
  final Sprite chassisSprite;
  final Sprite wheelSprite;
  final Sprite driverSprite;
  final void Function() onHeadImpact;

  late final Wheel rearWheel;
  late final Wheel frontWheel;
  late final DriverHead head;

  WheelJoint? _rearJoint;
  WheelJoint? _frontJoint;

  Throttle throttle = Throttle.none;

  // --- Flip tracking --------------------------------------------------
  //
  // The head is welded high on the chassis, so its mass really does make
  // the rover top-heavy (see GameConfig.headDensity). These two track the
  // consequences: a completed barrel roll, and simply landing on the roof.

  /// Radians rolled since the rover was last settled upright. Signed, so a
  /// roll one way then back cancels out rather than accumulating.
  double rollAccumulator = 0;

  /// Seconds spent continuously inverted.
  double invertedSeconds = 0;

  /// 1.0 = perfectly upright, 0 = on its side, -1.0 = fully inverted.
  double get uprightness => -body.worldVector(Vector2(0, -1)).y;

  bool get isUpright => uprightness >= GameConfig.uprightDot;

  bool get isInverted => uprightness <= -GameConfig.invertedDot;

  /// True once the rover has turned a full 360 without recovering.
  bool get hasRolledOver =>
      rollAccumulator.abs() >= GameConfig.rolloverRadians;

  /// True once it has been lying on its roof past the grace period.
  bool get hasSettledInverted =>
      invertedSeconds >= GameConfig.upsideDownGraceSeconds;

  void _trackFlip(double dt) {
    if (isUpright) {
      // Back on its wheels - forgive whatever rotation just happened.
      rollAccumulator = 0;
      invertedSeconds = 0;
      return;
    }

    rollAccumulator += body.angularVelocity * dt;
    invertedSeconds = isInverted ? invertedSeconds + dt : 0;
  }

  void resetFlipTracking() {
    rollAccumulator = 0;
    invertedSeconds = 0;
  }

  /// Forward speed along the chassis' own x axis, in m/s. Used by the HUD
  /// and by the brake logic.
  double get forwardSpeed {
    final forward = body.worldVector(Vector2(1, 0));
    return body.linearVelocity.dot(forward);
  }

  double get distanceTravelled =>
      math.max(0, body.position.x - spawn.x);

  @override
  Body createBody() {
    final shape = PolygonShape()
      ..setAsBoxXY(
        vehicle.chassisSize.x / 2,
        vehicle.chassisSize.y / 2,
      );

    final fixtureDef = FixtureDef(shape)
      ..density = vehicle.chassisDensity
      ..friction = GameConfig.chassisFriction
      ..restitution = GameConfig.chassisRestitution
      ..filter.categoryBits = GameConfig.categoryVehicle
      ..filter.maskBits = GameConfig.categoryTerrain | GameConfig.categoryPickup;

    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: spawn,
      userData: this,
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // --- Art on the chassis -------------------------------------------
    add(
      SpriteComponent(
        sprite: chassisSprite,
        anchor: Anchor.center,
        size: vehicle.spriteSize,
        position: vehicle.spriteOffset,
        priority: 1,
      ),
    );

    add(
      SpriteComponent(
        sprite: driverSprite,
        anchor: Anchor.center,
        size: vehicle.driverSize,
        position: vehicle.driverOffset,
        priority: 2,
      ),
    );

    // --- Wheels --------------------------------------------------------
    rearWheel = Wheel(
      spawn: spawn + vehicle.rearAnchor,
      sprite: wheelSprite,
      isFront: false,
      vehicle: vehicle,
    );
    frontWheel = Wheel(
      spawn: spawn + vehicle.frontAnchor,
      sprite: wheelSprite,
      isFront: true,
      vehicle: vehicle,
    );

    head = DriverHead(
      spawn: spawn + vehicle.headOffset,
      onGroundImpact: onHeadImpact,
      vehicle: vehicle,
    );

    // Joints need real bodies on both ends, and a body only exists once
    // its component has mounted. Awaiting that here would deadlock (the
    // mount queue is drained in update(), which can't run while onLoad is
    // still pending), so we fire-and-forget the adds and build the joints
    // lazily on the first tick where everything is ready.
    parent!.addAll([rearWheel, frontWheel, head]);
  }

  bool _jointsBuilt = false;

  /// True once the chassis, both wheels and the head all have live bodies.
  bool get _partsReady =>
      isMounted &&
      rearWheel.isMounted &&
      frontWheel.isMounted &&
      head.isMounted;

  void _buildJoints() {
    _rearJoint = _attachWheel(rearWheel);
    _frontJoint = _attachWheel(frontWheel);
    _weldHead();
    _jointsBuilt = true;
  }

  // ---------------------------------------------------------------------
  // JOINTS
  // ---------------------------------------------------------------------

  WheelJoint _attachWheel(Wheel wheel) {
    final def = WheelJointDef()
      ..initialize(
        body,
        wheel.body,
        wheel.body.position,
        GameConfig.suspensionAxis.clone(),
      )
      ..enableMotor = true
      ..motorSpeed = 0
      ..maxMotorTorque = 0
      // forge2d 0.13 takes the suspension spring as a frequency /
      // damping-ratio pair, so the config values go straight in.
      //
      // Box2D 2.4 (and forge2d's newer releases) instead want raw
      // stiffness/damping. If you bump the package and this stops
      // compiling, convert with:
      //   omega = 2*pi*f;  stiffness = m*omega^2;  damping = 2*m*zeta*omega
      ..frequencyHz = vehicle.suspensionFrequencyHz
      ..dampingRatio = vehicle.suspensionDampingRatio;

    // forge2d's WheelJoint has no translation limit, so the spring itself
    // is what stops the wheel - there is no hard stop at full travel.
    final joint = WheelJoint(def);
    world.createJoint(joint);
    return joint;
  }

  void _weldHead() {
    final def = WeldJointDef()
      ..initialize(body, head.body, head.body.position);
    world.createJoint(WeldJoint(def));
  }

  // ---------------------------------------------------------------------
  // DRIVE
  // ---------------------------------------------------------------------

  void _applyMotor(WheelJoint? joint, double speed, double torque) {
    if (joint == null) return;
    joint
      ..enableMotor(true)
      ..motorSpeed = speed
      ..setMaxMotorTorque(torque);
  }

  /// Torque the engine can actually deliver at the current wheel speed.
  ///
  /// The joint motor is a speed servo: given a flat torque limit it simply
  /// holds its setpoint up any slope it can grip, so hills never slow the
  /// machine and the game plays itself. Fading torque out as the wheels
  /// spin up is what makes a climb cost speed, and what makes a slope
  /// steep enough to stall you on.
  double _availableTorque(Wheel wheel) {
    // The motor acts on the wheel's spin *relative to the chassis*, which
    // is what the solver constrains - not its absolute angular velocity.
    final relativeSpin =
        (wheel.body.angularVelocity - body.angularVelocity).abs();
    final t =
        (relativeSpin / vehicle.engineMaxMotorSpeed).clamp(0.0, 1.0).toDouble();

    final fade = 1.0 - math.pow(t, vehicle.powerCurveExponent).toDouble();
    return vehicle.engineMaxTorque * fade.clamp(0.0, 1.0);
  }

  /// Quadratic air drag. Without it the servo would snap straight to its
  /// setpoint; with it, top speed is where available torque meets drag,
  /// so a headwind of a hill genuinely costs you.
  void _applyDrag() {
    final v = body.linearVelocity;
    final speed = v.length;
    if (speed < 0.2) return;
    body.applyForce(v.normalized()..scale(-vehicle.dragCoefficient * speed * speed));
  }

  /// [torqueScale] lets reverse and braking reuse the same power curve at
  /// reduced strength.
  void _driveAll(double speed, {double torqueScale = 1.0, double? fixedTorque}) {
    void drive(WheelJoint? joint, Wheel wheel, bool driven) {
      if (!driven) {
        _applyMotor(joint, 0, 0);
        return;
      }
      final torque = fixedTorque ?? _availableTorque(wheel) * torqueScale;
      _applyMotor(joint, speed, torque);
    }

    drive(_rearJoint, rearWheel, vehicle.rearWheelDrive);
    drive(_frontJoint, frontWheel, vehicle.frontWheelDrive);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!_jointsBuilt) {
      if (!_partsReady) return;
      _buildJoints();
    }

    _trackFlip(dt);

    switch (throttle) {
      case Throttle.forward:
        _driveAll(GameConfig.driveDirection * vehicle.engineMaxMotorSpeed);
        // Nose-up torque so hard acceleration pops a wheelie.
        body.applyTorque(
          GameConfig.driveDirection * -vehicle.chassisPitchTorque,
        );

      case Throttle.reverse:
        // Rolling forward + BRAKE == braking. Stationary or rolling
        // backward + BRAKE == reverse.
        if (forwardSpeed > 1.0) {
          _driveAll(0, fixedTorque: GameConfig.brakeTorque);
        } else {
          _driveAll(
            -GameConfig.driveDirection *
                vehicle.engineMaxMotorSpeed *
                GameConfig.reverseMotorSpeedFactor,
            torqueScale: GameConfig.reverseTorqueFactor,
          );
          body.applyTorque(
            GameConfig.driveDirection * vehicle.chassisPitchTorque * 0.5,
          );
        }

      case Throttle.none:
        // Motors off - angular damping on the wheels does the coasting.
        _driveAll(0, fixedTorque: 0);
    }

    _applyDrag();
  }

  void teardown() {
    rearWheel.removeFromParent();
    frontWheel.removeFromParent();
    head.removeFromParent();
    removeFromParent();
  }
}

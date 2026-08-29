import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../config.dart';
import 'driver_head.dart';
import 'wheel.dart';

/// Throttle state driven by the on-screen buttons.
enum Throttle { none, forward, reverse }

/// The rover: chassis body + two wheels on spring wheel-joints, with the
/// driver art and a welded head body on top.
///
/// [Rover] is the chassis BodyComponent itself; the wheels and head are
/// siblings in the physics world (joints can't cross component trees in
/// any meaningful way, so they all get added to the same world).
class Rover extends BodyComponent {
  Rover({
    required this.spawn,
    required this.chassisSprite,
    required this.wheelSprite,
    required this.driverSprite,
    required this.onHeadImpact,
  }) {
    renderBody = false;
    priority = 10;
  }

  final Vector2 spawn;
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
        GameConfig.chassisSize.x / 2,
        GameConfig.chassisSize.y / 2,
      );

    final fixtureDef = FixtureDef(shape)
      ..density = GameConfig.chassisDensity
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
        size: GameConfig.chassisSpriteSize,
        position: GameConfig.chassisSpriteOffset,
        priority: 1,
      ),
    );

    add(
      SpriteComponent(
        sprite: driverSprite,
        anchor: Anchor.center,
        size: GameConfig.driverSpriteSize,
        position: GameConfig.driverSpriteOffset,
        priority: 2,
      ),
    );

    // --- Wheels --------------------------------------------------------
    rearWheel = Wheel(
      spawn: spawn + GameConfig.rearWheelAnchor,
      sprite: wheelSprite,
      isFront: false,
    );
    frontWheel = Wheel(
      spawn: spawn + GameConfig.frontWheelAnchor,
      sprite: wheelSprite,
      isFront: true,
    );

    head = DriverHead(
      spawn: spawn + GameConfig.headOffset,
      onGroundImpact: onHeadImpact,
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
      ..frequencyHz = GameConfig.suspensionFrequencyHz
      ..dampingRatio = GameConfig.suspensionDampingRatio;

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

  void _driveAll(double speed, double torque) {
    if (GameConfig.rearWheelDrive) {
      _applyMotor(_rearJoint, speed, torque);
    } else {
      _applyMotor(_rearJoint, 0, 0);
    }
    if (GameConfig.frontWheelDrive) {
      _applyMotor(_frontJoint, speed, torque);
    } else {
      _applyMotor(_frontJoint, 0, 0);
    }
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
        _driveAll(
          GameConfig.driveDirection * GameConfig.engineMaxMotorSpeed,
          GameConfig.engineMaxTorque,
        );
        // Nose-up torque so hard acceleration pops a wheelie.
        body.applyTorque(
          GameConfig.driveDirection * -GameConfig.chassisPitchTorque,
        );

      case Throttle.reverse:
        // Rolling forward + BRAKE == braking. Stationary or rolling
        // backward + BRAKE == reverse.
        if (forwardSpeed > 1.0) {
          _driveAll(0, GameConfig.brakeTorque);
        } else {
          _driveAll(
            -GameConfig.driveDirection *
                GameConfig.engineMaxMotorSpeed *
                GameConfig.reverseMotorSpeedFactor,
            GameConfig.engineMaxTorque * GameConfig.reverseTorqueFactor,
          );
          body.applyTorque(
            GameConfig.driveDirection * GameConfig.chassisPitchTorque * 0.5,
          );
        }

      case Throttle.none:
        // Motors off - angular damping on the wheels does the coasting.
        _driveAll(0, 0);
    }
  }

  void teardown() {
    rearWheel.removeFromParent();
    frontWheel.removeFromParent();
    head.removeFromParent();
    removeFromParent();
  }
}

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flame_forge2d/flame_forge2d.dart';

import '../config.dart';
import 'vehicle.dart';

/// The driver's helmet, as a real (welded) physics body.
///
/// It exists purely so we can answer one question: "did the head hit the
/// ground?". The visible character art lives on the chassis; this body is
/// invisible.
class DriverHead extends BodyComponent with ContactCallbacks {
  DriverHead({
    required this.spawn,
    required this.onGroundImpact,
    required this.vehicle,
  }) {
    renderBody = false;
  }

  final Vector2 spawn;
  final VoidCallback onGroundImpact;
  final Vehicle vehicle;

  @override
  Body createBody() {
    final shape = CircleShape()..radius = vehicle.headRadius;

    final fixtureDef = FixtureDef(shape)
      ..density = vehicle.headDensity
      ..friction = 0.3
      ..restitution = 0.1
      ..filter.categoryBits = GameConfig.categoryDriver
      // Collides with terrain ONLY - never with its own rover.
      ..filter.maskBits = GameConfig.categoryTerrain;

    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: spawn,
      userData: this,
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void beginContact(Object other, Contact contact) {
    // maskBits already guarantee terrain, but stay explicit.
    onGroundImpact();
  }
}

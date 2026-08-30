import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../config.dart';
import 'vehicle.dart';

/// One rover wheel: a circle body with the tyre sprite riding on it.
class Wheel extends BodyComponent {
  Wheel({
    required this.spawn,
    required this.sprite,
    required this.isFront,
    required this.vehicle,
  }) {
    renderBody = false;
    priority = 5;
  }

  final Vector2 spawn;
  final Sprite sprite;
  final bool isFront;
  final Vehicle vehicle;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final diameter = vehicle.wheelRadius * 2 * vehicle.wheelSpriteScale;

    // The sprite is a child of the body, so it inherits the wheel's
    // rotation for free - the tyre visibly spins.
    add(
      SpriteComponent(
        sprite: sprite,
        anchor: Anchor.center,
        size: Vector2.all(diameter),
        position: Vector2.zero(),
      ),
    );
  }

  @override
  Body createBody() {
    final shape = CircleShape()..radius = vehicle.wheelRadius;

    final fixtureDef = FixtureDef(shape)
      ..density = vehicle.wheelDensity
      ..friction = vehicle.wheelFriction
      ..restitution = GameConfig.wheelRestitution
      ..filter.categoryBits = GameConfig.categoryVehicle
      ..filter.maskBits = GameConfig.categoryTerrain | GameConfig.categoryPickup;

    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: spawn,
      angularDamping: vehicle.wheelAngularDamping,
      userData: this,
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }
}

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../config.dart';
import 'vehicle.dart';

/// One rover wheel: a circle body with the tyre sprite riding on it.
class Wheel extends BodyComponent {
  Wheel({
    required this.spawn,
    required this.sprite,
    required this.mount,
    required this.vehicle,
  }) {
    renderBody = false;
    priority = 5;
  }

  final Vector2 spawn;
  final Sprite sprite;

  /// Where this wheel sits on the machine, and how big it is.
  final WheelMount mount;

  final Vehicle vehicle;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final diameter = mount.radius * 2 * mount.spriteScale;

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
    final shape = CircleShape()..radius = mount.radius;

    final fixtureDef = FixtureDef(shape)
      ..density = vehicle.wheelDensity
      ..friction = vehicle.wheelFriction
      ..restitution = GameConfig.wheelRestitution
      ..filter.categoryBits = GameConfig.categoryVehicle
      ..filter.maskBits =
          GameConfig.categoryTerrain | GameConfig.categoryPickup;

    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: spawn,
      angularDamping: vehicle.wheelAngularDamping,
      userData: this,
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }
}

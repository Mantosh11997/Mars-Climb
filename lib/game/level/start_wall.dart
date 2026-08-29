import 'package:flame_forge2d/flame_forge2d.dart';

import '../config.dart';
import '../terrain/terrain_generator.dart';

/// An invisible wall behind the start line.
///
/// Without it, holding BRAKE from the spawn reverses the rover off the back
/// of the map and into a fall-out game over, which reads as a bug rather
/// than a mistake. The far end deliberately has no wall: driving off the
/// end of the world is a real way to lose.
class StartWall extends BodyComponent {
  StartWall({required this.generator}) {
    renderBody = false;
  }

  final TerrainGenerator generator;

  static const double _height = 30.0;

  @override
  Body createBody() {
    final groundY = generator.surfaceY(0);

    final shape = EdgeShape()
      ..set(
        Vector2(0, groundY + 2),
        Vector2(0, groundY - _height),
      );

    final fixtureDef = FixtureDef(shape)
      ..friction = 0.0
      ..restitution = 0.02
      ..filter.categoryBits = GameConfig.categoryTerrain
      ..filter.maskBits = GameConfig.categoryVehicle;

    final bodyDef = BodyDef(
      type: BodyType.static,
      position: Vector2.zero(),
      userData: this,
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }
}

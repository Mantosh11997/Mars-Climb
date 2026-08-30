import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../config.dart';
import '../vehicle/rover.dart';
import '../vehicle/wheel.dart';

/// A jerry can of fuel sitting on the course.
///
/// Sensor body, so it never nudges the machine - it just reports the
/// contact and removes itself.
class FuelCan extends BodyComponent with ContactCallbacks {
  FuelCan({required this.spawn, required this.id, required this.sprite}) {
    renderBody = false;
    priority = 1;
  }

  final Vector2 spawn;

  /// Stable identity (chunk index + ordinal). Lets the terrain manager
  /// remember that this specific can was collected, so driving back over a
  /// re-streamed chunk doesn't hand out the same fuel twice.
  final String id;

  final Sprite sprite;

  /// Set by the terrain manager so the can can report itself collected.
  void Function(FuelCan can)? onCollected;

  bool _collected = false;
  double _bobPhase = 0;

  late final SpriteComponent _art;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Sized off the sprite's own aspect so it never looks squashed.
    const width = GameConfig.cellRadius * 2.4;
    final height = width * sprite.srcSize.y / sprite.srcSize.x;

    _art = SpriteComponent(
      sprite: sprite,
      anchor: Anchor.center,
      size: Vector2(width, height),
      position: Vector2.zero(),
    );
    add(_art);
  }

  @override
  Body createBody() {
    final shape = CircleShape()..radius = GameConfig.cellRadius;

    final fixtureDef = FixtureDef(shape)
      ..isSensor = true
      ..filter.categoryBits = GameConfig.categoryPickup
      ..filter.maskBits = GameConfig.categoryVehicle;

    final bodyDef = BodyDef(
      type: BodyType.static,
      position: spawn,
      userData: this,
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (_collected) return;
    if (other is! Rover && other is! Wheel) return;

    _collected = true;
    onCollected?.call(this);
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    // A slow hover, so a line of cans does not look like static clutter.
    _bobPhase += dt * 2.1;
    if (isMounted) {
      _art.position.y = math.sin(_bobPhase) * 0.11;
    }
  }
}

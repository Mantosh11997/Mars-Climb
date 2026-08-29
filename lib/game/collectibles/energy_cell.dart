import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../config.dart';
import '../vehicle/rover.dart';
import '../vehicle/wheel.dart';

/// A floating energy crystal. Sensor body, so it never nudges the rover -
/// it just reports the contact.
///
/// Drawn procedurally for now. To swap in art, load a sprite in
/// [MarsClimbGame.onLoad], pass it down here and add a SpriteComponent
/// child instead of overriding [render].
class EnergyCell extends BodyComponent with ContactCallbacks {
  EnergyCell({required this.spawn, required this.id}) {
    renderBody = false;
    priority = 1;
  }

  final Vector2 spawn;

  /// Stable identity (chunk index + ordinal). Lets the terrain manager
  /// remember that this specific cell was banked, so driving back over a
  /// re-streamed chunk doesn't hand out the same cell twice.
  final String id;

  /// Set by the game so the cell can report itself collected.
  void Function(EnergyCell cell)? onCollected;

  bool _collected = false;
  double _spin = 0;

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
    _spin += dt * 1.6;
  }

  @override
  void render(Canvas canvas) {
    const r = GameConfig.cellRadius;
    // Gentle bob, so a field of cells doesn't look like a static row.
    final bob = math.sin(_spin * 1.3) * 0.12;
    // Squash horizontally to fake a slow spin about the vertical axis.
    final squash = 0.35 + 0.65 * math.cos(_spin).abs();

    canvas
      ..save()
      ..translate(0, bob);

    // Glow.
    canvas.drawCircle(
      Offset.zero,
      r * 1.9,
      Paint()
        ..color = GameConfig.cellGlow.withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.35),
    );

    final crystal = Path()
      ..moveTo(0, -r * 1.35)
      ..lineTo(r * squash, -r * 0.35)
      ..lineTo(0, r * 1.35)
      ..lineTo(-r * squash, -r * 0.35)
      ..close();

    canvas
      ..drawPath(crystal, Paint()..color = GameConfig.cellCore)
      ..drawPath(
        crystal,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.07
          ..color = const Color(0xFFEAFFF8),
      );

    // Inner facet.
    canvas.drawPath(
      Path()
        ..moveTo(0, -r * 1.35)
        ..lineTo(r * squash * 0.45, -r * 0.35)
        ..lineTo(0, r * 1.35)
        ..close(),
      Paint()..color = const Color(0x66FFFFFF),
    );

    canvas.restore();
  }
}

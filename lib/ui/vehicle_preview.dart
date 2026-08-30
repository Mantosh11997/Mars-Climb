import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';

import '../game/vehicle/vehicle.dart';

/// A machine shown the way it actually drives - chassis with its wheels
/// fitted, not the bare chassis art.
///
/// Wheel placement comes from the same [Vehicle] anchors the physics uses,
/// converted back into fractions of the body sprite. So the garage can
/// never show a machine assembled differently from the one you drive.
class VehiclePreview extends StatelessWidget {
  const VehiclePreview({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    // Anchors are chassis-local; the art is drawn at spriteOffset from the
    // body centre, so shift into sprite space before normalising.
    Offset frac(Vector2 anchor) => Offset(
          0.5 + (anchor.x - vehicle.spriteOffset.x) / vehicle.spriteSize.x,
          0.5 + (anchor.y - vehicle.spriteOffset.y) / vehicle.spriteSize.y,
        );

    final rear = frac(vehicle.rearAnchor);
    final front = frac(vehicle.frontAnchor);
    final wheelFrac =
        vehicle.wheelRadius * 2 * vehicle.wheelSpriteScale / vehicle.spriteSize.x;

    return LayoutBuilder(
      builder: (context, c) {
        // The body art is 3:2; letterbox it inside whatever box we are
        // given so the wheel fractions stay true.
        final aspect = vehicle.spriteSize.x / vehicle.spriteSize.y;
        var w = c.maxWidth;
        var h = w / aspect;
        if (h > c.maxHeight) {
          h = c.maxHeight;
          w = h * aspect;
        }

        final wheelPx = wheelFrac * w;

        Widget wheelAt(Offset f) => Positioned(
              left: f.dx * w - wheelPx / 2,
              top: f.dy * h - wheelPx / 2,
              width: wheelPx,
              height: wheelPx,
              child: Image.asset(
                'assets/images/${vehicle.wheelAsset}',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            );

        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Wheels behind the body, so the arches overlap the tyre
                // exactly as they do in game.
                wheelAt(rear),
                wheelAt(front),
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/${vehicle.bodyAsset}',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

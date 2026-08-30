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

        Widget wheelAt(WheelMount mount) {
          final f = frac(mount.anchor);
          final px =
              mount.radius * 2 * mount.spriteScale / vehicle.spriteSize.x * w;
          return Positioned(
            left: f.dx * w - px / 2,
            top: f.dy * h - px / 2,
            width: px,
            height: px,
            child: Image.asset(
              'assets/images/${vehicle.wheelAsset}',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          );
        }

        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Wheels behind the body, so the arches overlap the tyre
                // exactly as they do in game. Every wheel the machine
                // carries, whether that is two or six.
                for (final mount in vehicle.wheels) wheelAt(mount),
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

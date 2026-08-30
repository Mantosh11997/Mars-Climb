import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';

import '../game/vehicle/vehicle.dart';

/// A machine shown the way it actually drives - chassis with its wheels
/// fitted and its driver aboard, not the bare chassis art.
///
/// Every position comes from the same [Vehicle] fields the physics uses,
/// converted back into fractions of the body sprite. So the garage can
/// never show a machine assembled differently from the one you drive -
/// which is the whole point: a wheel sitting wrong is visible here before
/// anyone has to drive the thing.
class VehiclePreview extends StatelessWidget {
  const VehiclePreview({
    super.key,
    required this.vehicle,
    this.showDriver = false,
  });

  final Vehicle vehicle;

  /// Whether to seat the driver on the machine.
  ///
  /// Off for the selection screens: picking a machine is about the machine,
  /// and a rider draped over it hides half the bodywork you are choosing
  /// between. On for the garage render test, which is how driver placement
  /// gets checked without building the game.
  final bool showDriver;

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

        Widget driver() {
          final f = frac(vehicle.driverOffset);
          final dw = vehicle.driverSize.x / vehicle.spriteSize.x * w;
          final dh = vehicle.driverSize.y / vehicle.spriteSize.y * h;
          return Positioned(
            left: f.dx * w - dw / 2,
            top: f.dy * h - dh / 2,
            width: dw,
            height: dh,
            child: Image.asset(
              'assets/images/${vehicle.driverAsset}',
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
                if (showDriver && vehicle.driverBehind) driver(),
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/${vehicle.bodyAsset}',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                // ...and in a cab he rides on top of it, as in game.
                if (showDriver && !vehicle.driverBehind) driver(),
              ],
            ),
          ),
        );
      },
    );
  }
}

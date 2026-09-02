import 'dart:ui' as ui;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/vehicle/vehicle.dart';

/// Does the driver actually sit on the machine?
///
/// Every driver placement is three hand-fitted numbers per vehicle, and a
/// wrong one is invisible in the source: `driverOffset: Vector2(0.1, -0.6)`
/// looks exactly as reasonable whether the rider lands on the grips or
/// hovers a metre behind the bike. That mistake shipped twice, and both
/// times it took a screenshot from a phone to find it.
///
/// So this checks the placement against the art itself. It composites each
/// driver onto its machine the way the game does and asserts two things
/// that were false in both broken builds:
///
///   1. The fists land on something. A grip, a bar, a steering column -
///      whatever the machine puts there, but not empty sky.
///   2. The driver overlaps the machine. A rider drawn floating clear of
///      the bodywork reads as broken however good the numbers look.
///
/// It cannot judge whether a pose looks *good* - that still needs the
/// garage render and a pair of eyes. It catches a driver placed on nothing,
/// which is the failure that actually happens.

/// How far from the fists an opaque pixel may be and still count as
/// something to hold, in metres. Generous: a bar end is small, and the
/// grips on a faired bike sit tucked behind the screen.
const double _handReach = 0.42;

/// The share of the driver's own pixels that must land on bodywork.
/// A standing rider only overlaps at the legs, so this is deliberately
/// low - it is a floating-driver check, not a pose score.
const double _minOverlap = 0.05;

class _Mask {
  _Mask(this.width, this.height, this.opaque);

  final int width;
  final int height;
  final List<bool> opaque;

  bool at(int x, int y) =>
      x >= 0 && y >= 0 && x < width && y < height && opaque[y * width + x];

  int get area => opaque.where((o) => o).length;
}

Future<_Mask> _load(String asset) async {
  final data = await rootBundle.load('assets/images/$asset');
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  final bytes =
      await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final rgba = bytes!.buffer.asUint8List();
  final w = frame.image.width;
  final h = frame.image.height;
  return _Mask(w, h, [
    for (var i = 0; i < w * h; i++) rgba[i * 4 + 3] > 24,
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cache = <String, _Mask>{};
  Future<_Mask> mask(String asset) async => cache[asset] ??= await _load(asset);

  test('every driver has hold of the machine and overlaps it', () async {
    final report = StringBuffer();

    for (final v in vehicles) {
      final body = await mask(v.bodyAsset);
      final driver = await mask(v.driverAsset);

      // Both sprites are drawn centred on the chassis, at their own size.
      // Work in chassis-local metres, then convert to body-sprite pixels.
      Vector2 toBodyPixel(Vector2 local) => Vector2(
            (0.5 + (local.x - v.spriteOffset.x) / v.spriteSize.x) * body.width,
            (0.5 + (local.y - v.spriteOffset.y) / v.spriteSize.y) * body.height,
          );

      final hand = driverHandAnchor[v.driverAsset];
      expect(hand, isNotNull,
          reason: '${v.driverAsset} has no entry in driverHandAnchor');

      // --- 1. the fists land on something ---------------------------
      final fist = Vector2(
        v.driverOffset.x + (hand!.x - 0.5) * v.driverSize.x,
        v.driverOffset.y + (hand.y - 0.5) * v.driverSize.y,
      );
      final fistPx = toBodyPixel(fist);
      final reachX = _handReach / v.spriteSize.x * body.width;
      final reachY = _handReach / v.spriteSize.y * body.height;

      var held = false;
      for (var dy = -reachY.round(); dy <= reachY.round() && !held; dy++) {
        for (var dx = -reachX.round(); dx <= reachX.round(); dx++) {
          if (body.at(fistPx.x.round() + dx, fistPx.y.round() + dy)) {
            held = true;
            break;
          }
        }
      }

      // --- 2. the driver overlaps the machine -----------------------
      // Walk the driver's pixels and ask what is under each one.
      final dw = v.driverSize.x / v.spriteSize.x * body.width;
      final dh = v.driverSize.y / v.spriteSize.y * body.height;
      final origin = toBodyPixel(
        Vector2(
          v.driverOffset.x - v.driverSize.x / 2,
          v.driverOffset.y - v.driverSize.y / 2,
        ),
      );

      var on = 0;
      var total = 0;
      for (var y = 0; y < driver.height; y += 3) {
        for (var x = 0; x < driver.width; x += 3) {
          if (!driver.at(x, y)) continue;
          total++;
          final bx = origin.x + x / driver.width * dw;
          final by = origin.y + y / driver.height * dh;
          if (body.at(bx.round(), by.round())) on++;
        }
      }
      final overlap = total == 0 ? 0.0 : on / total;

      report.writeln('${v.id.padRight(12)} '
          'hold ${held ? "yes" : "NO "}  '
          'overlap ${(overlap * 100).toStringAsFixed(0).padLeft(3)}%');

      expect(held, isTrue,
          reason: '${v.id}: the driver\'s fists close on nothing - there is '
              'no bodywork within ${_handReach}m of them. Its driverOffset '
              'does not put the hands on the grips.');
      expect(overlap, greaterThanOrEqualTo(_minOverlap),
          reason: '${v.id}: only ${(overlap * 100).toStringAsFixed(1)}% of '
              'the driver lands on the machine, so it is drawn floating '
              'clear of it.');
    }

    // ignore: avoid_print
    print(report);
  });
}

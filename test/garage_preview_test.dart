@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/vehicle/vehicle.dart';
import 'package:mars_climb/ui/vehicle_preview.dart';

/// Renders every machine with its wheels fitted, from the same anchors the
/// physics uses. This is how wheel placement gets checked - a number in
/// vehicle.dart tells you nothing about whether the tyre lands in the arch.
void main() {
  testWidgets('render the whole garage', (tester) async {
    const dir =
        String.fromEnvironment('PREVIEW_DIR', defaultValue: 'build/previews');
    Directory(dir).createSync(recursive: true);
    addTearDown(tester.view.reset);

    const cols = 3;
    final rows = (vehicles.length / cols).ceil();
    tester.view.physicalSize = Size(cols * 420, rows * 190);
    tester.view.devicePixelRatio = 1.0;

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFF8F3D22),
            child: GridView.count(
              crossAxisCount: cols,
              childAspectRatio: 420 / 190,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final v in vehicles)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Expanded(child: VehiclePreview(vehicle: v)),
                        Text(
                          '${v.name}  ·  ${v.wheelCount}W  ·  '
                          '${v.topSpeedKmh.round()} km/h',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      for (final v in vehicles) {
        for (final a in [v.bodyAsset, v.wheelAsset]) {
          await precacheImage(
            AssetImage('assets/images/$a'),
            tester.element(find.byType(MaterialApp)),
          );
        }
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/garage.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    // ignore: avoid_print
    print('wrote garage.png with ${vehicles.length} machines');
  });
}

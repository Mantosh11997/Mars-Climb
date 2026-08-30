@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/config.dart';
import 'package:mars_climb/game/vehicle/vehicle.dart';
import 'package:mars_climb/ui/course_select_screen.dart';
import 'package:mars_climb/ui/machine_select_screen.dart';

/// Both selection screens are plain Flutter, so they can be rendered and
/// eyeballed straight from a test.
void main() {
  Future<void> shoot(
    WidgetTester tester,
    String label,
    Widget screen,
    Size size,
  ) async {
    const dir =
        String.fromEnvironment('PREVIEW_DIR', defaultValue: 'build/previews');
    Directory(dir).createSync(recursive: true);

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: GameConfig.accent,
            brightness: Brightness.dark,
          ),
        ),
        home: RepaintBoundary(key: key, child: screen),
      ),
    );

    // Image.asset decodes on a real async path; without runAsync the
    // machine art silently never appears.
    await tester.runAsync(() async {
      for (final v in vehicles) {
        for (final asset in [v.bodyAsset, v.wheelAsset]) {
          await precacheImage(
            AssetImage('assets/images/$asset'),
            tester.element(find.byType(MaterialApp)),
          );
        }
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final name = '${label}_${size.width.toInt()}x${size.height.toInt()}.png';
    // toImage completes on the raster thread, which the fake-async zone
    // never drives - this must be inside runAsync or it hangs forever.
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    // ignore: avoid_print
    print('wrote $name');
  }

  testWidgets('render selection screens', (tester) async {
    addTearDown(tester.view.reset);
    for (final size in const [Size(920, 430), Size(1180, 540)]) {
      await shoot(tester, 'machines', const MachineSelectScreen(), size);
      await shoot(
        tester,
        'courses',
        CourseSelectScreen(vehicle: vehicles[2]),
        size,
      );
    }
  });

}

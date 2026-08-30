@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/config.dart';
import 'package:mars_climb/game/vehicle/vehicle.dart';
import 'package:mars_climb/ui/home_screen.dart';

/// The home screen is plain Flutter, so it can be rendered and eyeballed
/// straight from a test.
void main() {
  testWidgets('render home screen', (tester) async {
    const dir =
        String.fromEnvironment('PREVIEW_DIR', defaultValue: 'build/previews');
    Directory(dir).createSync(recursive: true);
    addTearDown(tester.view.reset);

    for (final size in const [Size(920, 430), Size(1180, 540)]) {
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
          home: RepaintBoundary(key: key, child: const HomeScreen()),
        ),
      );
      // Image.asset decodes on a real async path; without runAsync the
      // vehicle art silently never appears.
      await tester.runAsync(() async {
        for (final v in vehicles) {
          await precacheImage(
            AssetImage('assets/images/${v.bodyAsset}'),
            tester.element(find.byType(HomeScreen)),
          );
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final name = 'home_${size.width.toInt()}x${size.height.toInt()}.png';
      // toImage completes on the raster thread; the fake-async zone never
      // drives it, so this must run inside runAsync or it hangs forever.
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('wrote $name');
    }
  });
}

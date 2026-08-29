@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/config.dart';
import 'package:mars_climb/ui/level_select_screen.dart';

/// The level select is plain Flutter, so unlike the game world it can be
/// rendered and eyeballed straight from a test.
void main() {
  testWidgets('render level select', (tester) async {
    const dir =
        String.fromEnvironment('PREVIEW_DIR', defaultValue: 'build/previews');
    Directory(dir).createSync(recursive: true);

    for (final size in const [Size(2000, 900), Size(760, 1200)]) {
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
          home: RepaintBoundary(key: key, child: const LevelSelectScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

      // toImage completes on the raster thread, which the fake-async test
      // zone never drives - without runAsync this simply hangs forever.
      final name =
          'level_select_${size.width.toInt()}x${size.height.toInt()}.png';
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('wrote $name');
    }

    addTearDown(tester.view.reset);
  });
}

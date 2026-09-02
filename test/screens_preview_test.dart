@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/config.dart';
import 'package:mars_climb/game/progress/player_profile.dart';
import 'package:mars_climb/game/progress/profile_store.dart';
import 'package:mars_climb/game/vehicle/vehicle.dart';
import 'package:mars_climb/ui/progress_scope.dart';
import 'package:mars_climb/ui/course_select_screen.dart';
import 'package:mars_climb/ui/machine_select_screen.dart';

/// Both selection screens are plain Flutter, so they can be rendered and
/// eyeballed straight from a test.
/// A store holding a made-up profile, without touching device storage.
ProfileStore _storeWith(PlayerProfile profile) {
  final store = ProfileStore(starterVehicleId: rover.id);
  if (profile.coins > 0) store.award(profile.coins);
  for (final id in profile.ownedVehicles) {
    store.buyVehicle(id, 0);
  }
  for (final n in profile.completedLevels) {
    store.recordRun(levelNumber: n, distance: 0, finished: true);
  }
  return store;
}

void main() {
  Future<void> shoot(
    WidgetTester tester,
    String label,
    Widget screen,
    Size size, {
    PlayerProfile profile = PlayerProfile.fresh,
  }) async {
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
        // Every selection screen reads the profile for lock state and the
        // coin balance, so the preview has to stand one up. Seeding it is
        // also the only way to see the bought/unlocked half of the UI.
        home: ProgressScope(
          store: _storeWith(profile),
          child: RepaintBoundary(key: key, child: screen),
        ),
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
      await shoot(
        tester,
        'machines',
        const MachineSelectScreen(),
        size,
        // Enough money to see the buy button live rather than greyed.
        profile: const PlayerProfile(coins: 1450),
      );
      await shoot(
        tester,
        'courses',
        CourseSelectScreen(vehicle: vehicles[2]),
        size,
        // Two courses cleared, so the shot shows an open card, a best
        // distance and a locked one together.
        profile: const PlayerProfile(
          coins: 1450,
          completedLevels: {1, 2},
          bestDistance: {1: 520.0, 2: 411.0, 3: 96.0},
        ),
      );
    }
  });
}

@Tags(['capture'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/config.dart';
import 'package:mars_climb/game/level/level.dart';
import 'package:mars_climb/game/mars_climb_game.dart';
import 'package:mars_climb/game/progress/player_profile.dart';
import 'package:mars_climb/game/progress/profile_store.dart';
import 'package:mars_climb/game/vehicle/rover.dart';
import 'package:mars_climb/game/vehicle/vehicle.dart';
import 'package:mars_climb/ui/controls.dart';
import 'package:mars_climb/ui/home_screen.dart';
import 'package:mars_climb/ui/hud.dart';
import 'package:mars_climb/ui/machine_select_screen.dart';
import 'package:mars_climb/ui/outcome_overlay.dart';
import 'package:mars_climb/ui/palette.dart';
import 'package:mars_climb/ui/progress_scope.dart';

import 'support/test_fonts.dart';

/// Store-quality screenshots: two of the game, two of the app around it.
///
/// Tagged `capture` and excluded from normal runs.
///
///     flutter test --tags capture test/screenshot_test.dart \
///       --dart-define=SHOT_DIR=<dir>
///
/// These come out at 1920x1080 and use real fonts, unlike the `preview`
/// renders, which exist to be checked for layout bugs and are content with
/// Ahem boxes.
void main() {
  const dir = String.fromEnvironment('SHOT_DIR', defaultValue: 'build/shots');

  /// 1920x1080 of actual pixels, but as a phone produces them: 960x540
  /// logical at 2x, not 1920x1080 logical at 1x.
  ///
  /// The difference is the whole shot. These screens are laid out for a
  /// landscape phone with fixed type sizes, so giving them 1920 logical
  /// pixels does not enlarge the design, it strands it - 14 pt text adrift
  /// in a third of a screen of empty background. Rendering the phone
  /// layout at twice the density gives a crisp screenshot of the thing
  /// people will actually hold.
  const logical = Size(960, 540);
  const density = 2.0;

  setUpAll(loadRealFonts);

  /// A store with a made-up profile and no device storage behind it.
  ProfileStore storeWith(PlayerProfile profile) {
    final store = ProfileStore(starterVehicleId: rover.id);
    if (profile.coins > 0) store.award(profile.coins);
    for (final id in profile.ownedVehicles) {
      store.buyVehicle(id, 0);
    }
    profile.bestDistance.forEach((n, d) {
      store.recordRun(
        levelNumber: n,
        distance: d,
        finished: profile.hasCompleted(n),
      );
    });
    for (final n in profile.completedLevels) {
      store.recordRun(levelNumber: n, distance: 0, finished: true);
    }
    if (profile.lastVehicleId case final id?) store.setLastVehicle(id);
    return store;
  }

  /// The theme the app actually ships, plus Roboto so the text is text.
  ThemeData theme() => ThemeData.light(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Palette.pageGradient.first,
        colorScheme: ColorScheme.fromSeed(seedColor: GameConfig.accent),
      );

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name) async {
    // toImage completes on the raster thread, which the fake-async zone
    // never drives - this must be inside runAsync or it hangs forever.
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // pixelRatio, or the shot comes back at logical size - 960x540 -
      // however dense the view was configured to be.
      final image = await boundary.toImage(pixelRatio: density);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    // ignore: avoid_print
    print('wrote $name.png');
  }

  /// Drive [vehicle] on [level] to [distance] and photograph it there.
  ///
  /// The same driver the video capture uses, for the same reason: pitch has
  /// to be measured against the ground, not against horizontal, or the
  /// throttle gets cut on every slope past 17 degrees.
  Future<void> gameplay(
    WidgetTester tester,
    String name, {
    required Vehicle vehicle,
    required Level level,
    required double distance,
  }) async {
    final game = MarsClimbGame(level: level, vehicle: vehicle);
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme(),
        // Scaffold, because GameScreen has one and because without a
        // Material ancestor every label in the HUD and on the controls
        // renders as a yellow-underlined box - Flutter's "no text style
        // here" affordance, which looks exactly like a missing font and
        // sent me hunting one for a while.
        home: Scaffold(
          backgroundColor: Palette.gameLetterbox,
          body: RepaintBoundary(
            key: key,
            child: GameWidget<MarsClimbGame>(
              game: game,
              overlayBuilderMap: {
                Overlays.hud: (_, g) => Hud(game: g),
                Overlays.controls: (_, g) => Controls(game: g),
                Overlays.gameOver: (_, g) =>
                    OutcomeOverlay(game: g, onNextLevel: (_) {}, onQuit: () {}),
                Overlays.levelComplete: (_, g) =>
                    OutcomeOverlay(game: g, onNextLevel: (_) {}, onQuit: () {}),
              },
            ),
          ),
        ),
      ),
    );

    // runAsync and pump have to be interleaved: GameWidget builds the game
    // inside a FutureBuilder, so onLoad completing is not enough on its own.
    for (var i = 0; i < 80; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    for (var i = 0; i < 30; i++) {
      game.update(1 / 60);
      await tester.pump();
    }

    const dt = 1 / 60;
    var steps = 0;
    while (game.rover.body.position.x < distance &&
        !game.state.isOver &&
        steps < 60 * 200) {
      final x = game.rover.body.position.x;
      final ground = math.atan2(
        game.generator.surfaceY(x + 0.5) - game.generator.surfaceY(x - 0.5),
        1.0,
      );
      final pitch = game.rover.body.angle - ground;
      final rate = game.rover.body.angularVelocity;
      game.setThrottle(
        pitch < -0.60 || rate < -1.8
            ? Throttle.reverse
            : pitch < -0.38
                ? Throttle.none
                : Throttle.forward,
      );
      game.update(dt);
      // The pump is what mounts newly streamed terrain chunks. Without it
      // the machine drives off the end of the world at four chunks.
      await tester.pump();
      steps++;
    }

    // ignore: avoid_print
    print('$name: ${vehicle.name} on ${level.name} at '
        '${game.rover.body.position.x.toStringAsFixed(0)} m, '
        '${game.state.status.name}');
    await shoot(tester, key, name);
  }

  Future<void> screen(
    WidgetTester tester,
    String name,
    Widget child, {
    required PlayerProfile profile,
  }) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      ProgressScope(
        store: storeWith(profile),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme(),
          home: RepaintBoundary(key: key, child: child),
        ),
      ),
    );

    // Image.asset decodes on a real async path; without this the machine
    // art is simply missing from the shot.
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
    await tester.pump(const Duration(milliseconds: 600));

    await shoot(tester, key, name);
  }

  testWidgets('four screenshots', (tester) async {
    Directory(dir).createSync(recursive: true);
    tester.view.physicalSize =
        Size(logical.width * density, logical.height * density);
    tester.view.devicePixelRatio = density;
    addTearDown(tester.view.reset);

    // A player some way in: enough cleared for the campaign bar and the
    // stat tiles to say something, not so much that nothing is left locked.
    const played = PlayerProfile(
      coins: 2150,
      ownedVehicles: {'rover', 'dustdevil', 'gecko'},
      completedLevels: {1, 2, 3, 4},
      bestDistance: {
        1: 520.0,
        2: 640.0,
        3: 780.0,
        4: 900.0,
        5: 412.0,
      },
      lastVehicleId: 'dustdevil',
    );

    await gameplay(tester, '1_gameplay_verdant',
        vehicle: dustdevil, level: level5, distance: 150);
    await gameplay(tester, '2_gameplay_coliseum',
        vehicle: wasp, level: level9, distance: 190);
    await screen(tester, '3_home', const HomeScreen(), profile: played);
    await screen(tester, '4_garage', const MachineSelectScreen(),
        profile: played);

    for (final n in [
      '1_gameplay_verdant',
      '2_gameplay_coliseum',
      '3_home',
      '4_garage'
    ]) {
      expect(File('$dir/$n.png').existsSync(), isTrue);
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

@Tags(['capture'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/level/level.dart';
import 'package:mars_climb/game/mars_climb_game.dart';
import 'package:mars_climb/game/vehicle/rover.dart';
import 'package:mars_climb/game/vehicle/vehicle.dart';
import 'package:mars_climb/ui/controls.dart';
import 'package:mars_climb/ui/hud.dart';
import 'package:mars_climb/ui/outcome_overlay.dart';
import 'package:mars_climb/ui/palette.dart';

import 'support/test_fonts.dart';

/// Records real gameplay to a folder of PNG frames.
///
/// Tagged `capture` and excluded from every normal run: it asserts almost
/// nothing and takes minutes. It exists to produce footage, and to prove
/// the machines actually drive - which nothing else here does. Every
/// preview so far has been a still frame, so a rover that spawns inside the
/// ground or a wheel joint that locks solid would not have shown up in one.
///
/// It drives the *real* game: a MarsClimbGame stepped at a fixed 30 Hz with
/// its throttle set by [_Driver] below. Nothing here fakes a scene or moves
/// the camera by hand - what is recorded is what the physics did.
///
///     flutter test --tags capture test/gameplay_capture_test.dart \
///       --dart-define=CAPTURE_DIR=<dir>
///     python3 tool/make_clip.py <dir> <out.mp4>
void main() {
  const dir =
      String.fromEnvironment('CAPTURE_DIR', defaultValue: 'build/capture');

  /// Frames per second of the finished clip, and the physics step. Fixed,
  /// not wall-clock: a captured frame takes far longer than 33 ms to write,
  /// so stepping by real elapsed time would produce slow motion.
  const fps = 30;
  const dt = 1 / fps;

  /// Seconds of footage per shot. Six shots at five seconds each.
  const shotSeconds = 5;

  /// One shot: a machine, a course, and how far into the course to start.
  ///
  /// Starting some shots part-way along matters - every course begins on a
  /// flat apron, so six clips all taken from the start line would be six
  /// clips of flat ground.
  // Not const: the vehicles are `final` top-level values, not consts.
  final shots = <(String, Vehicle, Level, double)>[
    ('01_pathfinder_acidalia', rover, level1, 30),
    ('02_dustdevil_verdant', dustdevil, level5, 90),
    ('03_gecko_frostpine', gecko, level6, 120),
    ('04_trilobite_rustworks', trilobite, level7, 100),
    ('05_wasp_coliseum', wasp, level9, 140),
    ('06_cinder_cay', cinder, level11, 110),
  ];

  // Without these the HUD and the controls render every label as a
  // yellow-underlined box, and the footage looks like a placeholder.
  setUpAll(loadRealFonts);

  testWidgets('record gameplay', (tester) async {
    Directory(dir).createSync(recursive: true);

    // 16:9 at a size that encodes cleanly - both dimensions even, which
    // h.264 requires, and small enough that 900 frames fit in memory-free
    // sequence on disk rather than in RAM.
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var frameNumber = 0;

    for (final (name, vehicle, level, startAt) in shots) {
      final game = MarsClimbGame(level: level, vehicle: vehicle);
      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          // Scaffold, because GameScreen has one. Without a Material
          // ancestor every HUD label is drawn as a yellow-underlined box -
          // Flutter's "no text style here" affordance, which looks exactly
          // like a missing font.
          home: Scaffold(
            backgroundColor: Palette.gameLetterbox,
            body: RepaintBoundary(
              key: key,
              child: GameWidget<MarsClimbGame>(
                game: game,
                overlayBuilderMap: {
                  Overlays.hud: (_, g) => Hud(game: g),
                  Overlays.controls: (_, g) => Controls(game: g),
                  Overlays.gameOver: (_, g) => OutcomeOverlay(
                      game: g, onNextLevel: (_) {}, onQuit: () {}),
                  Overlays.levelComplete: (_, g) => OutcomeOverlay(
                      game: g, onNextLevel: (_) {}, onQuit: () {}),
                },
              ),
            ),
          ),
        ),
      );

      // onLoad decodes real sprites on a real async path; the fake-async
      // zone will not drive those futures, so without runAsync the world
      // comes back empty and every frame is backdrop.
      // The two have to be interleaved. runAsync alone lets the sprite
      // futures resolve but never rebuilds the tree, and GameWidget loads
      // the game inside a FutureBuilder - so onLoad completes and nothing
      // ever notices. Without a pump between each turn of the crank,
      // `game.rover` is still uninitialised when the first frame is asked
      // for.
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

      final driver = _Driver(game);

      // Drive to the starting point of the shot before recording, so the
      // footage opens on terrain rather than on the flat starting apron.
      // Capped, because a machine that cannot climb this course would
      // otherwise spin here forever.
      //
      // The pump is not optional. Terrain streams in as the rover advances,
      // but a new chunk only *mounts* when Flame processes its lifecycle
      // queue, and that happens on the widget pump rather than inside
      // game.update. Stepping physics without pumping produced four shots
      // that each drove happily to about 173 m - four chunks of 42 m - and
      // then fell through the bottom of a world that had stopped being
      // built.
      var warmUp = 0;
      while (game.rover.body.position.x < startAt &&
          !game.state.isOver &&
          warmUp < 150 * fps) {
        driver.step(dt);
        game.update(dt);
        await tester.pump();
        warmUp++;
      }

      for (var i = 0; i < shotSeconds * fps; i++) {
        driver.step(dt);
        game.update(dt);
        await tester.pump();

        // toImage completes on the raster thread, which the fake-async
        // zone never drives - this must be inside runAsync or it hangs
        // forever.
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          File('$dir/frame_${frameNumber.toString().padLeft(5, '0')}.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
        });
        frameNumber++;
      }

      // What the run actually did, printed so a clip that came out wrong
      // can be diagnosed without re-watching it.
      // ignore: avoid_print
      print('$name  ${vehicle.name} on ${level.name}: '
          'reached ${game.rover.body.position.x.toStringAsFixed(0)} m, '
          'status ${game.state.status.name}, '
          'flips ${driver.recoveries}');
    }

    // ignore: avoid_print
    print('wrote $frameNumber frames to $dir');
    expect(frameNumber, shots.length * shotSeconds * fps);
  }, timeout: const Timeout(Duration(minutes: 20)));
}

/// Holds the throttle, and tries not to end the run.
///
/// Deliberately simple - this is a camera operator, not a player.
///
/// The one thing it has to get right is measuring pitch **relative to the
/// ground**, not to horizontal. On a hill the chassis is supposed to be
/// pitched: a driver that compares the body angle to zero cuts the throttle
/// the moment the slope passes about 17 degrees, and then wonders why the
/// machine cannot climb. A first version did exactly that and spent twenty
/// seconds sliding up and down the same four metres of the opening hill,
/// which looked like a physics bug and was not one.
class _Driver {
  _Driver(this.game);

  final MarsClimbGame game;

  /// How many times it had to tap the brake to bring the nose down.
  /// Reported after each shot: a high count means that machine and that
  /// course make ugly footage.
  int recoveries = 0;

  void step(double dt) {
    if (game.state.isOver) {
      game.setThrottle(Throttle.none);
      return;
    }

    final x = game.rover.body.position.x;
    final ground = math.atan2(
      game.generator.surfaceY(x + 0.5) - game.generator.surfaceY(x - 0.5),
      1.0,
    );
    final pitch = game.rover.body.angle - ground;
    final rate = game.rover.body.angularVelocity;

    if (pitch < -0.60 || rate < -1.8) {
      // Nose well past the slope, or coming up fast. Tap the brake, which
      // is exactly what a player does to bring it back down.
      recoveries++;
      game.setThrottle(Throttle.reverse);
    } else if (pitch < -0.38) {
      game.setThrottle(Throttle.none);
    } else {
      game.setThrottle(Throttle.forward);
    }
  }
}

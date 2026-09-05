import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/mars_climb_game.dart';
import 'package:mars_climb/game/vehicle/rover.dart';
import 'package:mars_climb/game/vehicle/vehicle.dart';
import 'package:mars_climb/ui/controls.dart';
import 'package:mars_climb/ui/hud.dart';
import 'package:mars_climb/ui/outcome_overlay.dart';

/// Can you actually hold the throttle down?
///
/// Nothing tested this before. Every other test either measures the level
/// data, or teleports the rover and checks the ground under it - none of
/// them ever asked the machine to drive. Recording footage did, and found
/// that holding the throttle on the flat starting apron flipped the starter
/// machine onto its back within a second and then kept it spinning: 22
/// radians, three and a half turns, after six seconds.
///
/// The cause was `chassisPitchTorque`, applied as a bare constant on every
/// frame the throttle was down. A constant torque with nothing opposing it
/// is not a wheelie, it is an angular accelerator, and it was worst in the
/// air where there is no ground contact to argue with it.
void main() {
  Future<MarsClimbGame> boot(WidgetTester tester, Vehicle vehicle) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final game = MarsClimbGame(vehicle: vehicle);
    await tester.pumpWidget(
      MaterialApp(
        home: GameWidget<MarsClimbGame>(
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
    );

    // onLoad decodes real sprites on a real async path, and GameWidget
    // builds the game inside a FutureBuilder. runAsync lets the futures
    // resolve; the pump lets the tree notice. Both, interleaved, or
    // `game.rover` is never initialised.
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
    return game;
  }

  /// The chassis orientation, wrapped into a real angle. forge2d's own
  /// `angle` is unbounded - it counts every turn the body has ever made.
  double pitchOf(MarsClimbGame game) {
    final a = game.rover.body.angle;
    return math.atan2(math.sin(a), math.cos(a));
  }

  // NOTE ON WHAT THIS DOES NOT COVER. Gating the torque stopped the
  // runaway spin, and that is all it stopped. The starter machine still
  // reaches 180 degrees - still ends up on its back - if you hold full
  // throttle from a standstill on flat ground. That is a tuning question
  // (engineMaxTorque 62 against chassisPitchTorque 34 on a 3.4 m chassis is
  // a lot of both) and not something to quietly change under 19 machines
  // whose balance other tests depend on. It is a known gap, written down
  // in CLAUDE.md, not a solved problem.
  testWidgets('holding the throttle cannot spin the chassis without limit',
      (tester) async {
    final game = await boot(tester, rover);

    // It starts flat. If this is not true the rest of the test means
    // nothing, because every angle below is measured against it.
    expect(pitchOf(game).abs(), lessThan(0.05),
        reason: 'the starting apron is flat ground');

    var worstPitch = 0.0;
    for (var i = 0; i < 60 * 6; i++) {
      game.setThrottle(Throttle.forward);
      game.update(1 / 60);
      await tester.pump();
      worstPitch = math.max(worstPitch, pitchOf(game).abs());
    }

    final turns = game.rover.body.angle.abs() / (2 * math.pi);
    // ignore: avoid_print
    print('six seconds of throttle: ${turns.toStringAsFixed(2)} turns, '
        'worst pitch ${(worstPitch * 180 / math.pi).toStringAsFixed(0)} deg');

    expect(
      turns,
      lessThan(1.0),
      reason: 'the chassis must not keep rotating for as long as the '
          'throttle is held. Before the wheelie torque was gated this '
          'reached 3.5 turns in six seconds and was still accelerating. '
          'It can still tip past vertical - see the note above - but it '
          'can no longer spin',
    );
  });

  testWidgets('the wheelie torque cannot accelerate a free spin',
      (tester) async {
    // The airborne case, which is where an ungated torque is worst: no
    // ground contact, nothing to oppose it, so angular velocity only ever
    // climbed. Lifted clear of the ground and held on full throttle, the
    // spin must settle rather than run away.
    final game = await boot(tester, rover);

    final start = game.rover.body.position.clone();
    game.rover.body.setTransform(start..y -= 8, 0);

    var peak = 0.0;
    for (var i = 0; i < 60; i++) {
      game.setThrottle(Throttle.forward);
      game.update(1 / 60);
      await tester.pump();
      peak = math.max(peak, game.rover.body.angularVelocity.abs());
    }

    // ignore: avoid_print
    print('airborne peak spin: ${peak.toStringAsFixed(2)} rad/s');
    expect(peak, lessThan(4.0),
        reason: 'an ungated constant torque has no ceiling at all here');
  });
}

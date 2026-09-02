import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/level/level.dart';
import '../game/mars_climb_game.dart';
import '../game/progress/economy.dart';
import '../game/vehicle/vehicle.dart';
import 'controls.dart';
import 'hud.dart';
import 'outcome_overlay.dart';
import 'palette.dart';
import 'progress_scope.dart';

/// Hosts one run of one course.
///
/// A fresh [MarsClimbGame] per screen keeps level switching trivial: to
/// play another course we just push a new GameScreen rather than trying to
/// rebuild a live physics world in place.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.level,
    required this.vehicle,
    this.fuelMultiplier = 1.0,
  });

  final Level level;

  /// Already tuned with its fitted parts - the screen does not upgrade it.
  final Vehicle vehicle;

  /// Fuel capacity multiplier from the machine's tank part.
  final double fuelMultiplier;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final MarsClimbGame _game = MarsClimbGame(
    level: widget.level,
    vehicle: widget.vehicle,
    fuelMultiplier: widget.fuelMultiplier,
  );

  /// What this run paid, worked out once when it ends.
  ///
  /// Held here rather than recomputed by the overlay, because the first
  /// clear bonus depends on whether the course had been cleared BEFORE this
  /// run - and by the time the panel draws, it has been recorded.
  Payout? _payout;

  @override
  void initState() {
    super.initState();
    _game.state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _game.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!_game.state.isOver || _payout != null) return;

    final store = ProgressScope.read(context);
    final state = _game.state;
    final payout = payoutFor(
      level: state.level,
      distance: state.distance,
      cans: state.cells,
      finished: state.hasWon,
      alreadyCleared: store.profile.hasCompleted(state.level.number),
    );

    setState(() => _payout = payout);
    store
      ..recordRun(
        levelNumber: state.level.number,
        distance: state.distance,
        finished: state.hasWon,
      )
      ..award(payout.total);
  }

  /// Carry the chosen machine over to the next course.
  void _openLevel(Level level) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          level: level,
          vehicle: widget.vehicle,
          fuelMultiplier: widget.fuelMultiplier,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.gameLetterbox,
      body: GameWidget<MarsClimbGame>(
        game: _game,
        overlayBuilderMap: {
          Overlays.hud: (_, g) => Hud(game: g),
          Overlays.controls: (_, g) => Controls(game: g),
          Overlays.gameOver: (_, g) => OutcomeOverlay(
                game: g,
                payout: _payout,
                onNextLevel: _openLevel,
                onQuit: () => Navigator.of(context).pop(),
              ),
          Overlays.levelComplete: (_, g) => OutcomeOverlay(
                game: g,
                payout: _payout,
                onNextLevel: _openLevel,
                onQuit: () => Navigator.of(context).pop(),
              ),
        },
        loadingBuilder: (_) => const Center(
          child: CircularProgressIndicator(color: GameConfig.accent),
        ),
      ),
    );
  }
}

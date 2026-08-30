import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/level/level.dart';
import '../game/mars_climb_game.dart';
import '../game/vehicle/vehicle.dart';
import 'controls.dart';
import 'hud.dart';
import 'outcome_overlay.dart';

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
  });

  final Level level;
  final Vehicle vehicle;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final MarsClimbGame _game =
      MarsClimbGame(level: widget.level, vehicle: widget.vehicle);

  /// Carry the chosen machine over to the next course.
  void _openLevel(Level level) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(level: level, vehicle: widget.vehicle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF160B08),
      body: GameWidget<MarsClimbGame>(
        game: _game,
        overlayBuilderMap: {
          Overlays.hud: (_, g) => Hud(game: g),
          Overlays.controls: (_, g) => Controls(game: g),
          Overlays.gameOver: (_, g) => OutcomeOverlay(
                game: g,
                onNextLevel: _openLevel,
                onQuit: () => Navigator.of(context).pop(),
              ),
          Overlays.levelComplete: (_, g) => OutcomeOverlay(
                game: g,
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

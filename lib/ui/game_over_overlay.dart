import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/mars_climb_game.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.game});

  final MarsClimbGame game;

  @override
  Widget build(BuildContext context) {
    final s = game.state;

    return Container(
      color: const Color(0xCC160B08),
      alignment: Alignment.center,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: const Color(0xF21F110C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x55FF8A3D)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.gameOverTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: GameConfig.accent,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              s.gameOverBlurb,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Stat(label: 'DISTANCE', value: '${s.distance.floor()} m'),
                _Stat(label: 'CELLS', value: '${s.cells}'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: GameConfig.accent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: game.restart,
                child: const Text(
                  'REDEPLOY ROVER',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

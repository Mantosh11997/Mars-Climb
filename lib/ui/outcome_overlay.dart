import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/level/level.dart';
import '../game/mars_climb_game.dart';

/// End-of-run panel. Serves both outcomes: the level-complete card and
/// every way of losing, since they show the same run summary and differ
/// only in wording and colour.
class OutcomeOverlay extends StatelessWidget {
  const OutcomeOverlay({
    super.key,
    required this.game,
    required this.onNextLevel,
    required this.onQuit,
  });

  final MarsClimbGame game;

  /// Open a different course (used by "Next course").
  final void Function(Level level) onNextLevel;

  /// Leave this run and go back to the course list.
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final s = game.state;
    final won = s.hasWon;
    final accent = won ? GameConfig.cellCore : GameConfig.accent;
    final next = levelAfter(s.level);

    return Container(
      color: const Color(0xD9160B08),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Container(
          width: 420,
          margin: const EdgeInsets.symmetric(vertical: 24),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: const Color(0xF21F110C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                won ? Icons.flag_rounded : Icons.warning_amber_rounded,
                color: accent,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                s.outcomeTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                s.outcomeBlurb,
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
                  _Stat(
                    label: 'DISTANCE',
                    value: '${s.distance.floor()} m',
                  ),
                  _Stat(
                    label: 'COURSE',
                    value: '${(s.progress * 100).round()}%',
                  ),
                  _Stat(label: 'CELLS', value: '${s.cells}'),
                ],
              ),
              const SizedBox(height: 24),
              // Winning offers the next course first; losing offers a
              // retry first. Either way the other options stay one tap
              // away rather than forcing a trip through the menu.
              if (won && next != null)
                _PrimaryButton(
                  label: 'NEXT: ${next.name.toUpperCase()}',
                  color: accent,
                  onPressed: () => onNextLevel(next),
                )
              else
                _PrimaryButton(
                  label: won ? 'RUN IT AGAIN' : 'REDEPLOY ROVER',
                  color: accent,
                  onPressed: game.restart,
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SecondaryButton(
                      label: won ? 'REPLAY' : 'RETRY',
                      onPressed: game.restart,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SecondaryButton(
                      label: 'COURSES',
                      onPressed: onQuit,
                    ),
                  ),
                ],
              ),
              if (won && next == null) ...[
                const SizedBox(height: 12),
                const Text(
                  'That was the last course. Add another to `levels` in '
                  'game/level/level.dart.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: const Color(0xFF14100C),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: BorderSide(color: Colors.white.withOpacity(0.22)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          fontSize: 12,
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
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

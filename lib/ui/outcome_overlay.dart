import 'package:flutter/material.dart';

import 'palette.dart';
import '../game/level/level.dart';
import '../game/mars_climb_game.dart';
import '../game/progress/economy.dart';

/// End-of-run panel. Serves both outcomes: the level-complete card and
/// every way of losing, since they show the same run summary and differ
/// only in wording and colour.
class OutcomeOverlay extends StatelessWidget {
  const OutcomeOverlay({
    super.key,
    required this.game,
    this.payout,
    required this.onNextLevel,
    required this.onQuit,
  });

  final MarsClimbGame game;

  /// What the run earned. Null while it is still being worked out, and on
  /// the very first frame of the panel.
  final Payout? payout;

  /// Open a different course (used by "Next course").
  final void Function(Level level) onNextLevel;

  /// Leave this run and go back to the course list.
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final s = game.state;
    final won = s.hasWon;
    final accent = won ? Palette.success : Palette.danger;
    final next = levelAfter(s.level);

    return Container(
      color: Palette.scrim,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Container(
          width: 420,
          margin: const EdgeInsets.symmetric(vertical: 24),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Palette.surfaceOverGame,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.45), width: 2),
            boxShadow: Palette.lift(strong: true),
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
                  color: Palette.inkMuted,
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
              if (payout != null && !payout!.isEmpty) ...[
                const SizedBox(height: 18),
                _Earnings(payout: payout!),
              ],
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
                    color: Palette.inkFaint,
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

/// What the run paid, itemised.
///
/// Broken down rather than shown as one number, because the breakdown is
/// what teaches the economy: you can see that finishing is worth far more
/// than the distance, and that the first clear of a course is worth more
/// again.
class _Earnings extends StatelessWidget {
  const _Earnings({required this.payout});

  final Payout payout;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, int)>[
      ('Distance', payout.distance),
      if (payout.cans > 0) ('Fuel cans', payout.cans),
      if (payout.finish > 0) ('Course cleared', payout.finish),
      if (payout.firstClear > 0) ('First clear', payout.firstClear),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Palette.accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.accent.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          for (final (label, amount) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Palette.inkMuted,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '+$amount',
                    style: const TextStyle(
                      color: Palette.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 14, color: Palette.line),
          Row(
            children: [
              const Icon(Icons.paid_rounded, size: 17, color: Palette.accent),
              const SizedBox(width: 6),
              const Text(
                'EARNED',
                style: TextStyle(
                  color: Palette.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Text(
                '${payout.total}',
                style: const TextStyle(
                  color: Palette.accent,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
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
          foregroundColor: Palette.onAccent,
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
        foregroundColor: Palette.inkMuted,
        side: const BorderSide(color: Palette.line),
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
            color: Palette.inkFaint,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Palette.ink,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

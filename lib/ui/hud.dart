import 'package:flutter/material.dart';

import 'palette.dart';
import 'sound_toggle.dart';
import '../game/mars_climb_game.dart';

/// Top-of-screen telemetry: oxygen bar, energy cells, distance, speed.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.game});

  final MarsClimbGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: game.state,
        builder: (context, _) {
          final s = game.state;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _OxygenGauge(fraction: s.oxygenFraction)),
                const SizedBox(width: 14),
                _Readout(
                  icon: Icons.local_gas_station_outlined,
                  label: 'CANS',
                  value: '${s.cells}',
                ),
                const SizedBox(width: 10),
                _Readout(
                  icon: Icons.flag_outlined,
                  label: 'LEVEL ${s.level.number}',
                  value: '${s.distance.floor()} / ${s.level.finishX.floor()} m',
                  progress: s.progress,
                ),
                const SizedBox(width: 10),
                _Readout(
                  icon: Icons.speed_outlined,
                  label: 'SPEED',
                  value: '${(s.speed * 3.6).abs().round()} km/h',
                ),
                const SizedBox(width: 10),
                // Also here, not just on the home screen: wanting the
                // engine to shut up is something you discover mid-run, and
                // quitting the course to do it is not a fix.
                const SoundToggle(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OxygenGauge extends StatelessWidget {
  const _OxygenGauge({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    // Bar shifts from teal to amber to red as the cell drains.
    final color = fraction > 0.5
        ? Palette.success
        : fraction > 0.22
            ? Palette.warning
            : Palette.danger;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, size: 15, color: Palette.inkMuted),
              const SizedBox(width: 5),
              const Text(
                'FUEL',
                style: _labelStyle,
              ),
              const Spacer(),
              Text(
                '${(fraction * 100).round()}%',
                style: _labelStyle.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 9, color: Palette.track),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 140),
                  widthFactor: fraction,
                  child: Container(
                    height: 9,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.65), color],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.icon,
    required this.label,
    required this.value,
    this.progress,
  });

  final IconData icon;
  final String label;
  final String value;

  /// When set, a thin course-progress bar is drawn under the value.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Palette.inkMuted),
              const SizedBox(width: 5),
              Text(label, style: _labelStyle),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Palette.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              height: 1.1,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            // The width MUST be bounded. This panel sits in a Row without
            // Expanded, so it is laid out with unbounded width - and a
            // FractionallySizedBox under an infinite constraint throws.
            SizedBox(
              width: _progressBarWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(
                  children: [
                    Container(height: 4, color: Palette.track),
                    FractionallySizedBox(
                      widthFactor: progress!.clamp(0.0, 1.0),
                      child: Container(height: 4, color: Palette.accent),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Palette.surfaceOverGame,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.line),
        boxShadow: Palette.lift(),
      ),
      child: child,
    );
  }
}

/// Fixed so the bar has a bounded width in an unbounded Row slot.
const double _progressBarWidth = 132;

const _labelStyle = TextStyle(
  color: Palette.inkMuted,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.2,
);

import 'package:flutter/material.dart';

import '../game/config.dart';
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
                  icon: Icons.hexagon_outlined,
                  label: 'CELLS',
                  value: '${s.cells}',
                ),
                const SizedBox(width: 10),
                _Readout(
                  icon: Icons.terrain_outlined,
                  label: 'DISTANCE',
                  value: '${s.distance.floor()} m',
                ),
                const SizedBox(width: 10),
                _Readout(
                  icon: Icons.speed_outlined,
                  label: 'SPEED',
                  value: '${(s.speed * 3.6).abs().round()} km/h',
                ),
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
        ? GameConfig.cellCore
        : fraction > 0.22
            ? const Color(0xFFFFC24B)
            : const Color(0xFFFF5252);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, size: 15, color: Colors.white70),
              const SizedBox(width: 5),
              const Text(
                'FUEL CELL / O₂',
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
                Container(height: 9, color: const Color(0x33000000)),
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
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.white70),
              const SizedBox(width: 5),
              Text(label, style: _labelStyle),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              height: 1.1,
            ),
          ),
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
        color: const Color(0xCC1C0F0B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x33FF8A3D)),
      ),
      child: child,
    );
  }
}

const _labelStyle = TextStyle(
  color: Colors.white70,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.2,
);

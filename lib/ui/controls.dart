import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/mars_climb_game.dart';
import '../game/vehicle/rover.dart';

/// GAS and BRAKE/REVERSE, as a Flutter overlay on top of the game.
///
/// Both buttons are held, not tapped: pressing sets the throttle, letting
/// go clears it. Holding both is treated as "no throttle" so you can't
/// cheat the brake logic.
class Controls extends StatefulWidget {
  const Controls({super.key, required this.game});

  final MarsClimbGame game;

  @override
  State<Controls> createState() => _ControlsState();
}

class _ControlsState extends State<Controls> {
  bool _gas = false;
  bool _brake = false;

  void _apply() {
    final Throttle throttle;
    if (_gas && !_brake) {
      throttle = Throttle.forward;
    } else if (_brake && !_gas) {
      throttle = Throttle.reverse;
    } else {
      throttle = Throttle.none;
    }
    widget.game.setThrottle(throttle);
  }

  @override
  Widget build(BuildContext context) {
    // GameWidget puts each overlay in a Stack as a non-positioned child,
    // which gets LOOSE constraints and therefore aligns top-left. Without
    // an explicit Align the pedals sit in the top corners on top of the
    // HUD - which is exactly where they ended up before this.
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 22),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _PedalButton(
                label: 'BRAKE',
                icon: Icons.arrow_back_rounded,
                color: const Color(0xFF9A2C2C),
                pressed: _brake,
                onChanged: (v) {
                  setState(() => _brake = v);
                  _apply();
                },
              ),
              const Spacer(),
              _PedalButton(
                label: 'GAS',
                icon: Icons.arrow_forward_rounded,
                color: GameConfig.accent,
                pressed: _gas,
                onChanged: (v) {
                  setState(() => _gas = v);
                  _apply();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PedalButton extends StatelessWidget {
  const _PedalButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.pressed,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool pressed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Listener rather than GestureDetector: we want the raw down/up,
      // with no tap-vs-drag arbitration delay.
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onChanged(true),
      onPointerUp: (_) => onChanged(false),
      onPointerCancel: (_) => onChanged(false),
      child: AnimatedScale(
        scale: pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(pressed ? 0.92 : 0.62),
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(pressed ? 0.55 : 0.25),
                blurRadius: pressed ? 26 : 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 34),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/level/level.dart';
import '../game/level/level_stats.dart';
import '../game/vehicle/vehicle.dart';
import 'game_screen.dart';
import 'level_profile.dart';
import 'vehicle_stats.dart';

/// The garage: pick a machine, pick a course, launch.
///
/// Two horizontal carousels stacked. Both snap, both show their
/// neighbours peeking in so it reads as a rail you can drag rather than a
/// static row. The background takes the selected course's own sky, so
/// choosing a level previews its mood before you drive it.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _vehicleCtrl =
      PageController(viewportFraction: 0.52);
  late final PageController _levelCtrl = PageController(viewportFraction: 0.34);

  int _vehicleIndex = 0;
  int _levelIndex = 0;

  Vehicle get _vehicle => vehicles[_vehicleIndex];
  Level get _level => levels[_levelIndex];

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    _levelCtrl.dispose();
    super.dispose();
  }

  void _launch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(level: _level, vehicle: _vehicle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _level.theme;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.skyTop, theme.skyMid, theme.groundFillDeep],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(vehicle: _vehicle, level: _level),
              const _RailLabel('SELECT MACHINE'),
              // Flex rather than fixed heights: this is a landscape phone,
              // so vertical space is the scarce axis and dead space at the
              // bottom is very visible.
              Expanded(
                flex: 6,
                child: PageView.builder(
                  controller: _vehicleCtrl,
                  itemCount: vehicles.length,
                  onPageChanged: (i) => setState(() => _vehicleIndex = i),
                  itemBuilder: (_, i) => _VehicleCard(
                    vehicle: vehicles[i],
                    selected: i == _vehicleIndex,
                    onTap: () => _vehicleCtrl.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              ),
              _Dots(count: vehicles.length, index: _vehicleIndex),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 4, 26, 0),
                child: Text(
                  _vehicle.tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.62),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const _RailLabel('SELECT COURSE'),
              Expanded(
                flex: 5,
                child: PageView.builder(
                  controller: _levelCtrl,
                  itemCount: levels.length,
                  onPageChanged: (i) => setState(() => _levelIndex = i),
                  itemBuilder: (_, i) => _LevelCard(
                    level: levels[i],
                    selected: i == _levelIndex,
                    onTap: () => _levelCtrl.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _LaunchButton(onPressed: _launch),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.vehicle, required this.level});

  final Vehicle vehicle;
  final Level level;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'MARS CLIMB',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              shadows: [
                Shadow(
                  color: GameConfig.accent.withOpacity(0.6),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
          const Spacer(),
          _Pill(text: vehicle.name),
          const SizedBox(width: 8),
          _Pill(text: '${level.number}. ${level.name}'),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _RailLabel extends StatelessWidget {
  const _RailLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 4, 26, 4),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.6,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bars = VehicleBars.of(vehicle);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.88,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: selected ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 260),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.34),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? GameConfig.accent.withOpacity(0.85)
                    : Colors.white.withOpacity(0.10),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: GameConfig.accent.withOpacity(0.28),
                        blurRadius: 26,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Image.asset(
                    'assets/images/${vehicle.bodyAsset}',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  // Scale-to-fit rather than hand-tuned sizes: the card
                  // has to survive every phone aspect without clipping
                  // the stat bars.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 210,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final (label, value) in bars.rows)
                            _StatBar(label: label, value: value),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                children: [
                  Container(height: 4, color: Colors.white.withOpacity(0.10)),
                  FractionallySizedBox(
                    widthFactor: value.clamp(0.05, 1.0),
                    child: Container(height: 4, color: GameConfig.accent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final Level level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stats = LevelStats.of(level);
    final theme = level.theme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.9,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: selected ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 260),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? GameConfig.accent.withOpacity(0.85)
                    : Colors.white.withOpacity(0.10),
                width: selected ? 2 : 1,
              ),
              // The card wears the course's own sky.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [theme.skyTop, theme.skyLow],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${level.number}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              level.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _Tag(text: '${level.length.toInt()} m'),
                          const SizedBox(width: 6),
                          _Tag(text: '${stats.maxGradeDeg.round()}°'),
                          const SizedBox(width: 6),
                          _Tag(text: theme.name),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(child: LevelProfile(level: level)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index
                    ? GameConfig.accent
                    : Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

class _LaunchButton extends StatelessWidget {
  const _LaunchButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: GameConfig.accent,
            foregroundColor: const Color(0xFF1A0C04),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: onPressed,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded, size: 26),
              SizedBox(width: 8),
              Text(
                'LAUNCH',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

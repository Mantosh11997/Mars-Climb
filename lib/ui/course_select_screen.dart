import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/level/level.dart';
import '../game/level/level_stats.dart';
import '../game/vehicle/vehicle.dart';
import 'game_screen.dart';
import 'level_profile.dart';
import 'machine_select_screen.dart';
import 'vehicle_preview.dart';

/// Step two: pick a course, with the chosen machine carried through.
///
/// The background takes the highlighted course's own sky, so scrolling the
/// rail previews each level's mood before you commit to it.
class CourseSelectScreen extends StatefulWidget {
  const CourseSelectScreen({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  State<CourseSelectScreen> createState() => _CourseSelectScreenState();
}

class _CourseSelectScreenState extends State<CourseSelectScreen> {
  late final PageController _ctrl = PageController(viewportFraction: 0.56);
  int _index = 0;

  Level get _level => levels[_index];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
              Row(
                children: [
                  Expanded(
                    child: GarageHeader(
                      title: 'SELECT COURSE',
                      subtitle: 'STEP 2  ·  ${widget.vehicle.name.toUpperCase()}',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                  // A reminder of what you are driving, so you do not have
                  // to go back to check.
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: SizedBox(
                      width: 120,
                      height: 52,
                      child: VehiclePreview(vehicle: widget.vehicle),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: levels.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _CourseCard(
                    level: levels[i],
                    selected: i == _index,
                    onTap: () => _ctrl.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              ),
              GarageDots(count: levels.length, index: _index),
              const SizedBox(height: 10),
              Padding(
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
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GameScreen(
                          level: _level,
                          vehicle: widget.vehicle,
                        ),
                      ),
                    ),
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
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
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
        scale: selected ? 1.0 : 0.88,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: selected ? 1.0 : 0.46,
          duration: const Duration(milliseconds: 260),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? GameConfig.accent.withOpacity(0.9)
                    : Colors.white.withOpacity(0.10),
                width: selected ? 2 : 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [theme.skyTop, theme.skyLow],
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: GameConfig.accent.withOpacity(0.22),
                        blurRadius: 26,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${level.number}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.38),
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              level.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
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
                          _Tag(text: '${stats.maxGradeDeg.round()}° max'),
                          const SizedBox(width: 6),
                          _Tag(text: theme.name),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.32),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

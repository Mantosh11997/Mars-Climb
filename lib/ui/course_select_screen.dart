import 'package:flutter/material.dart';

import '../game/level/level.dart';
import '../game/level/level_stats.dart';
import '../game/vehicle/vehicle.dart';
import 'game_screen.dart';
import 'level_profile.dart';
import 'machine_select_screen.dart';
import 'palette.dart';
import 'progress_scope.dart';
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
            // The page stays light; the selected course still tints the
            // foot of it, so swiping between courses feels like moving
            // between places.
            colors: [
              Palette.pageGradient[0],
              Palette.pageGradient[1],
              Color.lerp(Palette.pageGradient[2], theme.skyLow, 0.35)!,
            ],
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
                      subtitle:
                          'STEP 2  ·  ${widget.vehicle.name.toUpperCase()}',
                      onBack: () => Navigator.of(context).pop(),
                      showWallet: true,
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
                    unlocked: ProgressScope.of(context)
                        .profile
                        .canPlay(levels[i].number),
                    best: ProgressScope.of(context)
                        .profile
                        .bestOn(levels[i].number),
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
                  child: Builder(builder: (context) {
                    final profile = ProgressScope.of(context).profile;
                    final open = profile.canPlay(_level.number);
                    // The machine goes into the run already tuned, so the
                    // physics never has to know that upgrades exist.
                    final fitted = profile.upgradesFor(widget.vehicle.id);

                    return FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: open ? Palette.accent : Palette.track,
                        foregroundColor:
                            open ? Palette.onAccent : Palette.inkFaint,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: open
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => GameScreen(
                                    level: _level,
                                    vehicle: widget.vehicle.tuned(fitted),
                                    fuelMultiplier:
                                        Vehicle.tankMultiplier(fitted),
                                  ),
                                ),
                              )
                          : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            open
                                ? Icons.play_arrow_rounded
                                : Icons.lock_rounded,
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            open ? 'LAUNCH' : 'LOCKED',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
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
    required this.unlocked,
    required this.best,
    required this.selected,
    required this.onTap,
  });

  final Level level;

  /// Whether the previous course has been cleared.
  final bool unlocked;

  /// Furthest reached here, in metres. Zero if never attempted.
  final double best;
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
                color: selected ? Palette.accent : Palette.line,
                width: selected ? 2 : 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [theme.skyTop, theme.skyLow],
              ),
              boxShadow: Palette.lift(strong: selected),
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
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: LevelProfile(level: level)),
                      // A locked course still shows its silhouette and its
                      // numbers. Hiding them would make the campaign a
                      // corridor; showing them makes it a horizon.
                      if (!unlocked)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.45),
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_rounded,
                                    color: Colors.white70, size: 26),
                                SizedBox(height: 6),
                                Text(
                                  'CLEAR THE PREVIOUS COURSE',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (best > 0)
                        Positioned(
                          right: 10,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              'BEST ${best.floor()} m',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
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

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.34),
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

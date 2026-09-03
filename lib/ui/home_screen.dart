import 'package:flutter/material.dart';

import '../build_info.dart';
import '../game/level/level.dart';
import '../game/progress/player_profile.dart';
import '../game/vehicle/vehicle.dart';
import 'coin_badge.dart';
import 'course_select_screen.dart';
import 'game_screen.dart';
import 'machine_select_screen.dart';
import 'palette.dart';
import 'progress_scope.dart';

/// Where the game starts.
///
/// The garage used to be the first screen, which made the app open on a
/// question - "which machine?" - before it had told you anything. This
/// answers first: what this is, how far you have got, and one button that
/// puts you straight back on the next course you have not cleared.
///
/// Laid out for landscape, which is the only orientation the game runs in:
/// identity and progress on the left, the things you can press on the
/// right.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProgressScope.of(context).profile;

    final nextNumber = profile.nextLevelNumber(levels.length);
    final nextLevel = levels.firstWhere((l) => l.number == nextNumber);

    // The machine PLAY will use: the last one taken out if it is still
    // owned, otherwise the starter. Never an unowned machine, however the
    // save got into that state.
    final machine = vehicles.firstWhere(
      (v) => v.id == profile.lastVehicleId && profile.owns(v.id),
      orElse: () => rover,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Palette.pageGradient,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 12, 26, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: _Identity(profile: profile, next: nextLevel),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 5,
                  child: _Actions(
                    nextLevel: nextLevel,
                    machine: machine,
                    cleared: profile.hasCompleted(nextLevel.number),
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

class _Identity extends StatelessWidget {
  const _Identity({required this.profile, required this.next});

  final PlayerProfile profile;

  /// The course PLAY will start. Named on this side too, because the
  /// button only has room for the name and this has room for the place.
  final Level next;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'MARS CLIMB',
          style: TextStyle(
            color: Palette.ink,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'ELEVEN COURSES  ·  NINETEEN MACHINES',
            maxLines: 1,
            style: TextStyle(
              color: Palette.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.6,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            _Stat(
              label: 'COURSES',
              value: '${profile.clearedCount}',
              of: '${levels.length}',
            ),
            const SizedBox(width: 12),
            _Stat(
              label: 'MACHINES',
              value: '${profile.ownedCount}',
              of: '${vehicles.length}',
            ),
            const SizedBox(width: 12),
            _Stat(
              label: 'DRIVEN',
              value: '${profile.totalDistance.floor()}',
              of: 'm',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _UpNext(level: next, best: profile.bestOn(next.number)),
        const Spacer(),
        const Text(
          'BUILD $buildId',
          style: TextStyle(
            color: Palette.inkFaint,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

/// What the course behind PLAY actually is.
///
/// The button can only fit a name. This says where it is and how long it
/// runs, so the decision to press it is made on the course rather than on
/// the word PLAY.
class _UpNext extends StatelessWidget {
  const _UpNext({required this.level, required this.best});

  final Level level;

  /// Furthest reached here so far. Zero means never attempted, which is
  /// worth saying differently from "got 40 m in".
  final double best;

  @override
  Widget build(BuildContext context) {
    final reached = best <= 0
        ? 'NOT ATTEMPTED'
        : '${best.floor()} m of ${level.length.floor()} m reached';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.line),
        boxShadow: Palette.lift(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'UP NEXT  ·  COURSE ${level.number}',
            style: const TextStyle(
              color: Palette.accent,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            level.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Palette.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            level.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Palette.inkMuted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            reached,
            style: const TextStyle(
              color: Palette.inkFaint,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// One headline number with its unit or total underneath it.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.of});

  final String label;
  final String value;

  /// The denominator, or a unit. Shown small next to the value so "3" reads
  /// as "3 of 11" rather than as a bare count.
  final String of;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.line),
        boxShadow: Palette.lift(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Palette.inkMuted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Palette.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                of.length > 2 ? of : '/$of',
                style: const TextStyle(
                  color: Palette.inkFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.nextLevel,
    required this.machine,
    required this.cleared,
  });

  final Level nextLevel;
  final Vehicle machine;

  /// True only when every course has been cleared, in which case PLAY is a
  /// replay of the last one rather than a next step.
  final bool cleared;

  void _play(BuildContext context) {
    final store = ProgressScope.read(context);
    store.setLastVehicle(machine.id);
    final fitted = store.profile.upgradesFor(machine.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          level: nextLevel,
          vehicle: machine.tuned(fitted),
          fuelMultiplier: Vehicle.tankMultiplier(fitted),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(alignment: Alignment.centerRight, child: CoinBadge()),
        const Spacer(),
        // PLAY carries what it will actually do, because a button that
        // silently picks a course and a machine for you should say which.
        SizedBox(
          height: 74,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Palette.accent,
              foregroundColor: Palette.onAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: () => _play(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_rounded, size: 34),
                const SizedBox(width: 10),
                // Flexible and clipped: the subtitle is a course name and
                // a machine name joined, and the longest pair is wider
                // than the button on a small landscape phone.
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cleared ? 'PLAY AGAIN' : 'PLAY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        '${nextLevel.name}  ·  ${machine.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Secondary(
                icon: Icons.garage_rounded,
                label: 'GARAGE',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MachineSelectScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Secondary(
                icon: Icons.flag_rounded,
                label: 'COURSES',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CourseSelectScreen(vehicle: machine),
                  ),
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }
}

class _Secondary extends StatelessWidget {
  const _Secondary({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Palette.ink,
          backgroundColor: Palette.surface,
          side: const BorderSide(color: Palette.line),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

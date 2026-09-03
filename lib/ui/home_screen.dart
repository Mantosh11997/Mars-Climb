import 'package:flutter/material.dart';

import '../build_info.dart';
import '../game/level/level.dart';
import '../game/progress/player_profile.dart';
import '../game/vehicle/vehicle.dart';
import 'click.dart';
import 'coin_badge.dart';
import 'course_select_screen.dart';
import 'game_screen.dart';
import 'machine_select_screen.dart';
import 'palette.dart';
import 'progress_scope.dart';
import 'sound_toggle.dart';
import 'vehicle_preview.dart';

/// Where the game starts.
///
/// The garage used to be the first screen, which made the app open on a
/// question - "which machine?" - before it had told you anything. This
/// answers first: what this is, how far you have got, and one button that
/// puts you straight back on the next course you have not cleared.
///
/// Laid out for landscape, which is the only orientation the game runs in:
/// identity and progress on the left, the machine and the things you can
/// press on the right.
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
            padding: const EdgeInsets.fromLTRB(26, 10, 26, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: _Identity(profile: profile, next: nextLevel),
                ),
                const SizedBox(width: 22),
                Expanded(
                  flex: 5,
                  child: _Actions(
                    nextLevel: nextLevel,
                    machine: machine,
                    everythingCleared:
                        profile.clearedCount >= levels.length,
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
      children: [
        const _Title(),
        const SizedBox(height: 11),
        _CampaignBar(cleared: profile.clearedCount, total: levels.length),
        const SizedBox(height: 11),
        Row(
          children: [
            _Stat(
              label: 'COURSES',
              value: '${profile.clearedCount}',
              of: '${levels.length}',
            ),
            const SizedBox(width: 10),
            _Stat(
              label: 'MACHINES',
              value: '${profile.ownedCount}',
              of: '${vehicles.length}',
            ),
            const SizedBox(width: 10),
            _Stat(
              label: 'DRIVEN',
              value: '${profile.totalDistance.floor()}',
              of: 'm',
            ),
          ],
        ),
        const SizedBox(height: 11),
        Flexible(child: _UpNext(level: next, best: profile.bestOn(next.number))),
        // Pins the build stamp to the bottom of the column, so the slack on
        // a tall screen collects in one deliberate gap instead of leaving
        // the whole left side floating above an empty third.
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

/// The wordmark.
///
/// Two weights on one line rather than one word: "MARS" in outline and
/// "CLIMB" solid reads as a logo at a glance, where a single run of bold
/// capitals reads as a heading on a form.
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'MARS',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  height: 1,
                  // Outlined, so the two halves of the name are told apart
                  // by weight rather than by colour alone.
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.6
                    ..color = Palette.ink,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'CLIMB',
                style: TextStyle(
                  color: Palette.accent,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'ELEVEN COURSES  ·  NINETEEN MACHINES',
            maxLines: 1,
            style: TextStyle(
              color: Palette.inkMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.6,
            ),
          ),
        ),
      ],
    );
  }
}

/// How much of the campaign is behind you, as one bar of eleven segments.
///
/// Segments rather than a continuous bar: eleven courses is few enough to
/// count, and a filled block per course tells you *which* run is next in a
/// way a 27%-full bar does not.
class _CampaignBar extends StatelessWidget {
  const _CampaignBar({required this.cleared, required this.total});

  final int cleared;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    // The next course is outlined rather than filled: it is
                    // neither done nor out of reach, and it is the one the
                    // eye should land on.
                    color: i < cleared ? Palette.accent : Palette.track,
                    border: i == cleared
                        ? Border.all(color: Palette.accent, width: 1.4)
                        : null,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Text(
          cleared >= total
              ? 'CAMPAIGN COMPLETE'
              : '$cleared OF $total COURSES CLEARED',
          style: const TextStyle(
            color: Palette.inkFaint,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

/// What the course behind PLAY actually is.
///
/// The button can only fit a name. This says where it is and how far you
/// got last time, so the decision to press it is made on the course rather
/// than on the word PLAY.
class _UpNext extends StatelessWidget {
  const _UpNext({required this.level, required this.best});

  final Level level;

  /// Furthest reached here so far. Zero means never attempted, which is
  /// worth saying differently from "got 40 m in".
  final double best;

  @override
  Widget build(BuildContext context) {
    final attempted = best > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
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
          const SizedBox(height: 7),
          // Best distance as a bar as well as a number, because "412 m" only
          // means something next to how long the course is.
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(height: 5, color: Palette.track),
                FractionallySizedBox(
                  widthFactor: (best / level.length).clamp(0.0, 1.0),
                  child: Container(height: 5, color: Palette.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            attempted
                ? '${best.floor()} m of ${level.length.floor()} m'
                : 'NOT ATTEMPTED  ·  ${level.length.floor()} m',
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 7, 11, 8),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Palette.inkMuted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
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
            ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.nextLevel,
    required this.machine,
    required this.everythingCleared,
  });

  final Level nextLevel;
  final Vehicle machine;

  /// True only when every course has been cleared, in which case PLAY is a
  /// replay of the last one rather than a next step.
  final bool everythingCleared;

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
        const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [SoundToggle(), SizedBox(width: 10), CoinBadge()],
        ),
        const SizedBox(height: 8),
        // The machine you are about to drive, assembled. The home screen
        // had no art on it at all, which made the game look like a menu.
        Expanded(child: _MachineCard(machine: machine)),
        const SizedBox(height: 10),
        // PLAY carries what it will actually do, because a button that
        // silently picks a course and a machine for you should say which.
        SizedBox(
          height: 66,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Palette.accent,
              foregroundColor: Palette.onAccent,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: clicky(() => _play(context)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_rounded, size: 32),
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
                        everythingCleared ? 'PLAY AGAIN' : 'PLAY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
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
        const SizedBox(height: 10),
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
            const SizedBox(width: 10),
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
      ],
    );
  }
}

/// The current machine, assembled, with its name and top speed.
class _MachineCard extends StatelessWidget {
  const _MachineCard({required this.machine});

  final Vehicle machine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.line),
        boxShadow: Palette.lift(),
      ),
      child: Column(
        children: [
          Expanded(child: VehiclePreview(vehicle: machine)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              machine.name.toUpperCase(),
              maxLines: 1,
              style: const TextStyle(
                color: Palette.ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
              ),
            ),
          ),
          Text(
            '${machine.topSpeedKmh.round()} km/h',
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
      height: 46,
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
        onPressed: clicky(onPressed),
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

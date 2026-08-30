import 'package:flutter/material.dart';

import '../build_info.dart';

import '../game/vehicle/vehicle.dart';
import 'palette.dart';
import 'course_select_screen.dart';
import 'vehicle_preview.dart';
import 'vehicle_stats.dart';

/// Step one: pick a machine.
///
/// Deliberately its own screen. Cramming the machine and course rails onto
/// one page left both of them squeezed on a landscape phone, and made the
/// choice feel like a form rather than a garage.
class MachineSelectScreen extends StatefulWidget {
  const MachineSelectScreen({super.key});

  @override
  State<MachineSelectScreen> createState() => _MachineSelectScreenState();
}

class _MachineSelectScreenState extends State<MachineSelectScreen> {
  late final PageController _ctrl = PageController(viewportFraction: 0.62);
  int _index = 0;

  Vehicle get _vehicle => vehicles[_index];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              const _Header(
                title: 'MARS CLIMB',
                subtitle: 'STEP 1  ·  SELECT MACHINE',
                // Only on the first screen: enough to tell one APK from
                // another, small enough to ignore while playing.
                trailing: 'BUILD $buildId',
              ),
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: vehicles.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _MachineCard(
                    vehicle: vehicles[i],
                    selected: i == _index,
                    onTap: () => _ctrl.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              ),
              _Dots(count: vehicles.length, index: _index),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 8, 26, 0),
                child: Text(
                  _vehicle.tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Palette.inkMuted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.accent,
                      foregroundColor: Palette.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CourseSelectScreen(vehicle: _vehicle),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'CHOOSE COURSE',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 22),
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

class _MachineCard extends StatelessWidget {
  const _MachineCard({
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
        scale: selected ? 1.0 : 0.86,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: selected ? 1.0 : 0.42,
          duration: const Duration(milliseconds: 260),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Palette.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? Palette.accent : Palette.line,
                width: selected ? 2 : 1,
              ),
              boxShadow: Palette.lift(strong: selected),
            ),
            child: Column(
              children: [
                // The machine as it actually drives: wheels fitted.
                Expanded(flex: 5, child: VehiclePreview(vehicle: vehicle)),
                const SizedBox(height: 8),
                Text(
                  vehicle.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Palette.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 250,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (label, value) in bars.rows)
                            _StatBar(label: label, value: value),
                          const SizedBox(height: 2),
                          Text(
                            '${vehicle.topSpeedKmh.round()} km/h top speed',
                            style: const TextStyle(
                              color: Palette.inkFaint,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: const TextStyle(
                color: Palette.inkMuted,
                fontSize: 9,
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
                  Container(height: 5, color: Palette.track),
                  FractionallySizedBox(
                    widthFactor: value.clamp(0.05, 1.0),
                    child: Container(height: 5, color: Palette.accent),
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

/// Shared chrome, used by both selection screens.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  /// Optional quiet note pinned to the far end of the bar.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 24, 2),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: Palette.inkMuted,
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Palette.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Palette.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                ),
              ),
            ],
          ),
          if (trailing != null) ...[
            const Spacer(),
            Text(
              trailing!,
              style: const TextStyle(
                color: Palette.inkFaint,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? Palette.accent : Palette.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// Exposed so the course screen can reuse the same chrome.
class GarageHeader extends StatelessWidget {
  const GarageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final String? trailing;

  @override
  Widget build(BuildContext context) => _Header(
        title: title,
        subtitle: subtitle,
        onBack: onBack,
        trailing: trailing,
      );
}

class GarageDots extends StatelessWidget {
  const GarageDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => _Dots(count: count, index: index);
}

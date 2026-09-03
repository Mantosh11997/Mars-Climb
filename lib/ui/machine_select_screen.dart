import 'package:flutter/material.dart';

import '../game/vehicle/vehicle.dart';
import 'coin_badge.dart';
import 'palette.dart';
import 'progress_scope.dart';
import 'upgrade_sheet.dart';
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
              _Header(
                title: 'GARAGE',
                // Says where you are in the rail and how much of it is
                // yours, so the screen answers "how far through this am I"
                // without a separate progress panel.
                subtitle: 'MACHINE ${_index + 1} OF ${vehicles.length}'
                    '  ·  ${ProgressScope.of(context).profile.ownedCount} OWNED',
                onBack: Navigator.of(context).canPop()
                    ? () => Navigator.of(context).pop()
                    : null,
                showWallet: true,
              ),
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: vehicles.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _MachineCard(
                    vehicle: vehicles[i],
                    owned:
                        ProgressScope.of(context).profile.owns(vehicles[i].id),
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _vehicle.tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Palette.inkMuted,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const _NextUnlock(),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: _ActionRow(vehicle: _vehicle),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// What you can do with the machine in front of you.
///
/// One row that changes shape with ownership: an unowned machine offers
/// only its price, an owned one offers the workshop and the way forward.
/// Two different screens for that would be one screen too many.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final owned = store.profile.owns(vehicle.id);
    final affordable = store.profile.coins >= vehicle.price;

    if (!owned) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: affordable ? Palette.accent : Palette.track,
            foregroundColor: affordable ? Palette.onAccent : Palette.inkFaint,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: affordable
              ? () => ProgressScope.read(context)
                  .buyVehicle(vehicle.id, vehicle.price)
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_open_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                affordable
                    ? 'UNLOCK  ·  ${vehicle.price}'
                    : 'NEEDS ${vehicle.price - store.profile.coins} MORE',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          height: 48,
          width: 116,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Palette.ink,
              side: const BorderSide(color: Palette.line),
              // Zero, because OutlinedButton's default horizontal padding
              // plus the icon and label is wider than the button.
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => UpgradeSheet.show(context, vehicle),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.build_rounded, size: 17),
                SizedBox(width: 6),
                Text(
                  'TUNE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
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
                  builder: (_) => CourseSelectScreen(vehicle: vehicle),
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
      ],
    );
  }
}

/// The cheapest machine you cannot afford yet, and how far off it is.
///
/// Nineteen machines is a long rail to scroll before the prices tell you
/// anything, so the screen names the next realistic purchase itself. Draws
/// nothing at all once everything is owned rather than showing an empty
/// slot - there is no goal left to advertise.
class _NextUnlock extends StatelessWidget {
  const _NextUnlock();

  @override
  Widget build(BuildContext context) {
    final profile = ProgressScope.of(context).profile;

    Vehicle? target;
    for (final v in vehicles) {
      if (profile.owns(v.id)) continue;
      if (target == null || v.price < target.price) target = v;
    }
    if (target == null) return const SizedBox.shrink();

    final short = target.price - profile.coins;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            short <= 0 ? Icons.lock_open_rounded : Icons.lock_rounded,
            size: 13,
            color: short <= 0 ? Palette.accent : Palette.inkFaint,
          ),
          const SizedBox(width: 6),
          Text(
            short <= 0
                ? 'NEXT: ${target.name.toUpperCase()}  ·  AFFORDABLE'
                : 'NEXT: ${target.name.toUpperCase()}  ·  $short TO GO',
            style: const TextStyle(
              color: Palette.inkMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MachineCard extends StatelessWidget {
  const _MachineCard({
    required this.vehicle,
    required this.owned,
    required this.selected,
    required this.onTap,
  });

  final bool owned;

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
                // The machine as it actually drives: wheels fitted. An
                // unowned one is greyed rather than hidden - you should be
                // able to see exactly what you are saving up for.
                Expanded(
                  flex: 5,
                  child: Opacity(
                    opacity: owned ? 1.0 : 0.42,
                    child: VehiclePreview(vehicle: vehicle),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!owned) ...[
                      const Icon(Icons.lock_rounded,
                          size: 15, color: Palette.inkFaint),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        vehicle.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: owned ? Palette.ink : Palette.inkMuted,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),
                  ],
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
    this.showWallet = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  /// Optional quiet note pinned to the far end of the bar.
  final String? trailing;

  /// Whether to show the coin balance. On wherever you can spend.
  final bool showWallet;

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
          // Flexible, because the bar now carries a wallet and a build
          // label as well as the title, and a long machine name in the
          // subtitle was enough to overflow it.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Palette.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Spacer(),
          if (showWallet) ...[
            const CoinBadge(),
            const SizedBox(width: 10),
          ],
          if (trailing != null) ...[
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
    this.showWallet = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final String? trailing;
  final bool showWallet;

  @override
  Widget build(BuildContext context) => _Header(
        title: title,
        subtitle: subtitle,
        onBack: onBack,
        trailing: trailing,
        showWallet: showWallet,
      );
}

class GarageDots extends StatelessWidget {
  const GarageDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => _Dots(count: count, index: index);
}

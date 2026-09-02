import 'package:flutter/material.dart';

import '../game/progress/profile_store.dart';

/// Puts the one [ProfileStore] where every screen can reach it.
///
/// There is exactly one profile per app, and three screens plus the outcome
/// panel all read the coin balance and the lock state. Passing it down four
/// constructors would mean every screen knowing about the ones after it, so
/// it goes overhead instead.
class ProgressScope extends StatefulWidget {
  const ProgressScope({super.key, required this.store, required this.child});

  final ProfileStore store;
  final Widget child;

  /// The store, and a rebuild whenever it changes.
  static ProfileStore of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ProgressInherited>();
    assert(scope != null, 'No ProgressScope above this widget');
    return scope!.store;
  }

  /// The store without subscribing. For callbacks that only want to spend
  /// or award, and would otherwise rebuild the whole screen to do it.
  static ProfileStore read(BuildContext context) {
    final scope = context
        .getElementForInheritedWidgetOfExactType<_ProgressInherited>()!
        .widget as _ProgressInherited;
    return scope.store;
  }

  @override
  State<ProgressScope> createState() => _ProgressScopeState();
}

class _ProgressScopeState extends State<ProgressScope> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) => _ProgressInherited(
        store: widget.store,
        // Rebuild dependents whenever the profile changes: buying a machine
        // in the garage has to light up the course it unlocks.
        version: widget.store.profile.hashCode ^
            widget.store.profile.coins ^
            widget.store.profile.ownedVehicles.length ^
            widget.store.profile.completedLevels.length,
        child: widget.child,
      );
}

class _ProgressInherited extends InheritedWidget {
  const _ProgressInherited({
    required this.store,
    required this.version,
    required super.child,
  });

  final ProfileStore store;
  final int version;

  @override
  bool updateShouldNotify(_ProgressInherited old) => old.version != version;
}

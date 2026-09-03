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
  static ProfileStore of(BuildContext context) =>
      (context.dependOnInheritedWidgetOfExactType<_ProgressInherited>() ??
              _missing(context))
          .store;

  /// The store without subscribing. For callbacks that only want to spend
  /// or award, and would otherwise rebuild the whole screen to do it.
  static ProfileStore read(BuildContext context) => ((context
              .getElementForInheritedWidgetOfExactType<_ProgressInherited>()
              ?.widget as _ProgressInherited?) ??
          _missing(context))
      .store;

  /// A named failure rather than a null dereference.
  ///
  /// An assert would say nothing in a release build, where a widget that
  /// throws during build renders as an unexplained grey box. This at least
  /// names the cause in a crash log, and says what the fix is - which is
  /// almost always that the scope was put below MaterialApp instead of
  /// above it, so pushed routes cannot see it.
  static Never _missing(BuildContext context) => throw FlutterError.fromParts([
        ErrorSummary(
            'No ProgressScope found above ${context.widget.runtimeType}.'),
        ErrorHint(
          'ProgressScope must sit ABOVE MaterialApp. Dialogs, bottom sheets '
          'and pushed screens are routes on MaterialApp\'s Navigator, so a '
          'scope placed at `home` is invisible to all of them.',
        ),
      ]);

  @override
  State<ProgressScope> createState() => _ProgressScopeState();
}

class _ProgressScopeState extends State<ProgressScope> {
  /// Bumped on every change. A counter rather than a hash of the profile:
  /// exact, cheap, and it cannot miss an edit that happens to hash the same.
  int _version = 0;

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

  void _onChanged() => setState(() => _version++);

  @override
  Widget build(BuildContext context) => _ProgressInherited(
        store: widget.store,
        // Rebuild dependents whenever the profile changes: buying a machine
        // in the garage has to light up the course it unlocks.
        version: _version,
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

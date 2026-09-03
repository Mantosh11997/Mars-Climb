import 'package:flutter/foundation.dart';

import '../game/audio/game_audio.dart';

/// Give a button its click.
///
/// Wraps the callback rather than replacing the widget. There are a dozen
/// button styles across five screens; a `SoundButton` would mean either
/// rewriting all of them or having two kinds of button that look identical
/// and behave differently.
///
/// Passing null straight through matters. A disabled button is disabled by
/// having a null callback, so returning a non-null wrapper around one would
/// make every greyed-out button pressable, clicking at you and doing
/// nothing.
VoidCallback? clicky(VoidCallback? action) {
  if (action == null) return null;
  return () {
    GameAudio.instance.play(Sfx.tap);
    action();
  };
}

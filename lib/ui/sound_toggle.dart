import 'package:flutter/material.dart';

import '../game/audio/game_audio.dart';
import 'palette.dart';
import 'progress_scope.dart';

/// Turn the sound off.
///
/// Works with or without saved progress. Where there is a [ProgressScope]
/// the setting is read from and written to the profile, so it survives a
/// restart; where there is not - the game can be built standalone, and a
/// test does exactly that - it falls back to the audio player's own mute
/// and simply is not remembered. Requiring the scope here made the HUD, and
/// therefore the whole game, impossible to build without saved progress.
///
/// The profile rather than the player is the source of truth when both
/// exist. Those two can disagree: a player that failed to open an audio
/// session is silent while the preference still says sound is on. The
/// setting is the honest thing to show, because it is the thing the button
/// changes.
class SoundToggle extends StatefulWidget {
  const SoundToggle({super.key});

  @override
  State<SoundToggle> createState() => _SoundToggleState();
}

class _SoundToggleState extends State<SoundToggle> {
  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.maybeOf(context);
    final on = store?.profile.soundOn ?? !GameAudio.instance.isMuted;

    return Semantics(
      button: true,
      label: on ? 'Sound on' : 'Sound off',
      child: GestureDetector(
        onTap: () {
          if (store != null) {
            store.setSound(!on);
          } else {
            GameAudio.instance.setMuted(on);
          }
          // With a store the scope rebuilds this; without one nothing else
          // will, so ask for it either way rather than leaving the icon
          // showing the old state half the time.
          setState(() {});

          // Fired after the change, so switching sound back on is audible
          // and switching it off is not - a click on the way to silence is
          // a contradiction.
          if (!on) GameAudio.instance.play(Sfx.tap);
        },
        child: Container(
          width: 38,
          height: 34,
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Palette.line),
            boxShadow: Palette.lift(),
          ),
          child: Icon(
            on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            size: 18,
            color: on ? Palette.accent : Palette.inkFaint,
          ),
        ),
      ),
    );
  }
}

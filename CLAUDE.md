# Mars Climb — working notes

An original Hill Climb Racing–style game. Flutter + Flame + Forge2D.
Read this before exploring; it is here so you do not have to re-derive it.

## Environment

```bash
export PATH="/opt/flutter/bin:$PATH"     # Flutter 3.24.5 lives here
flutter analyze                          # must be clean before committing
flutter test --exclude-tags=preview      # the asserting tests
python3 tool/make_sounds.py              # rebuilds every file in assets/audio
```

- **No Android SDK in this container.** `dl.google.com` is blocked by the
  egress proxy, so the APK is only ever proven by CI. Never claim a build
  works from here.
- **No `gh` CLI.** GitHub is reachable only through the `mcp__github__*`
  tools (load via ToolSearch).
- Branch: `claude/mars-climb-flutter-prototype-5xw3zz`.
- Scratch files go in the session scratchpad, never `/tmp` or the repo.

## Pinned versions — do not bump casually

`flame 1.19.0` ↔ `flame_forge2d 0.18.2` ↔ `forge2d 0.13.1` are a verified
set. 0.18.2 requires flame ^1.19.0; earlier pairs do not resolve.
Audio is `audioplayers` **not** `flame_audio`, on purpose: flame_audio is
pinned against a flame version and would drag that trio forward.
CI pins `JAVA_VERSION: 17` and that is load-bearing — the Flutter 3.24.5
Android template ships Gradle 8.3, which rejects Java 21.

## Layout

```
lib/game/
  audio/game_audio.dart  one service, every sound, never throws
  config.dart            gravity, camera, terrain, category bits
  state/game_state.dart  the listenable run: fuel, distance, outcome
  mars_climb_game.dart   Forge2DGame; takes a Level + a (tuned) Vehicle
  level/                 Level data, LevelTheme palettes, stats, finish line
  terrain/               generator (fbm), streaming manager, chunks
  vehicle/               Vehicle data + Rover physics (N wheels)
  world/                 backdrop, scenery props
  progress/              profile, economy, upgrades, store
lib/ui/                  screens, palette, overlays
tool/                    python sprite pipeline; make_sounds.py (audio)
assets/audio/            generated - never edit by hand, regenerate
```

**Data, not code.** A level is a `Level` + a `LevelTheme` (+ optional
`SceneryStyle`). A machine is a `Vehicle` + two PNGs. Adding either should
touch no logic.

## Invariants learned the hard way

Each of these cost a debugging session. Do not undo them.

1. **`ChainShape.createChain` throws** on vertices closer than forge2d's
   linear slop (0.005 m), and the throw happens inside
   `BodyComponent.onLoad` — so the chunk silently never mounts, with no
   crash and no log. `TerrainGenerator.sample()` computes x from the index
   rather than accumulating, and drops a trailing point within
   `minVertexSeparation`.
2. **Forge2D's `WheelJoint` motor is a speed servo**, not an engine. With a
   flat torque cap it holds its setpoint up any slope it can grip and the
   game plays itself. Difficulty comes from the power curve
   (`powerCurveExponent`) plus quadratic drag, not from lowering top speed.
3. **Atmospheric perspective.** In every `LevelTheme`, the mountain bands
   must step *lighter* as they recede, and all of them must be lighter than
   `groundFill`. Inverted, distant scenery reads as a hole in the world.
4. **`GameWidget` overlays get loose constraints** and align top-left. Wrap
   in an explicit `Align`.
5. **Use the default `MaxViewport`.** `FixedResolutionViewport` letterboxes
   and clips.
6. **`ProgressScope` must sit ABOVE `MaterialApp`.** Dialogs, sheets and
   pushed screens are routes on MaterialApp's Navigator, so a scope at
   `home` is invisible to all of them — and in release that is an
   unexplained grey box. Pinned by `test/navigation_test.dart`.
7. **`RenderRepaintBoundary.toImage()` completes on the raster thread** and
   hangs forever in a widget test without `tester.runAsync`. Same for
   `Image.asset` decoding.
8. **Preview code must call the game's own code.** `render_preview_test`
   once built chunks by hand and rendered a world the game never built,
   proving nothing. Scenery placement lives in `sceneryForChunk()` so the
   preview and the streaming manager share it.

9. **Sound is decoration and must never be load-bearing.** `GameAudio` is
   off until `warmUp()` succeeds and turns itself off permanently after one
   failure, so a widget test or a device with no audio never reaches the
   plugin. The same rule bit the widget layer: putting `SoundToggle` in the
   HUD with a required `ProgressScope` made the *game* unbuildable without
   saved progress, which `terrain_streaming_test` caught. Hence
   `ProgressScope.maybeOf`. Pinned by `test/audio_test.dart`.
10. **A looping WAV needs whole cycles and no DC offset.** `engine.wav` is
    generated at a length that divides evenly by its fundamental, its noise
    windowed to zero at both cycle ends, and its mean subtracted. Miss any
    of the three and the loop seam is a click ~56 times a second - a
    rattle, not a click. `tool/make_sounds.py` explains each one.

## Verification workflow

The preview tests write PNGs instead of asserting; **look at them**, do not
reason about them.

```bash
D=<scratchpad>
flutter test --tags preview --dart-define=PREVIEW_DIR=$D
```

- `render_preview_test` → one frame per level (`theme_N_*.png`)
- `garage_preview_test` → all machines with wheels + driver fitted
- `screens_preview_test` → the selection screens

`tool/grid_overlay.py <outdir> <slug>` lays a percentage grid over a sprite
so wheel axles and handlebar grips can be read off directly. That is how
every `WheelMount.anchor` and `driverOffset` was measured — guessing from
fractions produced visibly wrong wheels twice.

## Current state

- **11 courses**, 520 m → 1600 m, each a distinct place (4 Mars, then
  meadow, snow, refinery, moor, arena, desert, beach). Level 1 is
  deliberately bare ground.
- **19 machines**: 5 buggies, 7 bikes, 7 trikes. In side view a reverse
  trike's front wheels share an x, so trikes are 2-axle here; wheel counts
  above 2 mean extra *axles*.
- **Audio**: engine loop (volume from throttle, pitch from wheel speed),
  coin, crash, finish, fail, low-oxygen alarm, UI tap, purchase. Mute is
  saved with the profile and toggled from the home screen and the HUD.
- **Progression**: coins from distance/cans/finishing, machine prices,
  4 upgrade parts × 5 levels, courses gated on clearing the previous one,
  saved to `shared_preferences` as one JSON string.
- Tests enforce *rules*, not numbers: courses stay inside their slope
  budget, no course locks everyone out, upgrading never reorders which
  machine grips best, a save survives a round trip.

## Known gaps — say these plainly, do not paper over them

- **Nothing has been playtested.** Every handling and economy number is
  reasoned, not driven.
- `prospector` and `vesper` sheets cannot be split — wheels drawn attached
  to the body. They need regenerating.
- `compass_body.png` has a blue background bloom.
- The backdrop is three noise ridges. It cannot do interiors, so the
  refinery is a yard and the arena is outdoors rather than the roofed
  spaces in the references. Background layers would improve the look more
  than better props would.
- **Nothing has been heard.** Every sound is synthesised by
  `tool/make_sounds.py` and was checked numerically (peak, DC, loop seam,
  envelope shape) because this container has no audio output. They are
  placeholders and sound like a handheld console. Replacing one is a file
  swap: same name, same 22050 Hz mono.
- No music, only effects.

## House style

- Commit messages explain **why**, and name what was wrong before. Bugs get
  their root cause recorded, not just the fix.
- Comments explain reasoning and non-obvious constraints, not mechanics.
- Report honestly: if something is unverified, say so.

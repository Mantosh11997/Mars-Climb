# Mars Climb

A Hill-Climb-Racing-style rover game set on Mars, built with **Flutter + Flame + Forge2D**.

---

## 1. Getting it running

This repo contains the Dart source and assets only — no platform folders. Generate them once:

```bash
flutter create . --project-name mars_climb --org com.marsclimb --platforms=android,ios,web
flutter pub get
flutter run
```

Or let CI do it: **Actions → Build APK → Run workflow**, then download the APK from
the run's Artifacts. See [`.github/workflows/README.md`](.github/workflows/README.md).

`flutter create .` will not overwrite `lib/`, `assets/` or `pubspec.yaml`'s dependency
block, but **do check `pubspec.yaml` afterwards** and re-add the `assets:` section if
it got rewritten.

### Pinned versions

| Package | Version | Note |
|---|---|---|
| `flame` | `1.19.0` | pinned exactly |
| `flame_forge2d` | `0.18.2` | pinned exactly — must match the flame version |
| `forge2d` | `0.13.1` | transitive, via `flame_forge2d` |
| Flutter SDK | `3.24.5` | what CI pins and what this was verified against |

`flame` and `flame_forge2d` version-lock hard: `flame_forge2d 0.18.2` requires
`flame ^1.19.0` and will refuse to resolve against anything else. If you bump one, bump
the other from the [flame_forge2d compatibility table](https://pub.dev/packages/flame_forge2d).

---

## 2. Where the art goes

```
assets/images/car_body.png    <- rover chassis, no wheels, facing right
assets/images/wheel.png       <- one wheel, centred in a square canvas
assets/images/character.png   <- driver, head attached, facing right
```

All three are already in place. They're declared in `pubspec.yaml` via the
directory entry:

```yaml
flutter:
  assets:
    - assets/images/
```

Flame resolves sprite paths relative to `assets/images/`, so `loadSprite('wheel.png')`
is the correct call — no `assets/images/` prefix.

All three are cleanly cut out — alpha is effectively binary (fully transparent or
fully opaque, with a normal antialiased rim). The orange glow visible in a preview is
just how a viewer paints the transparent area; it is not baked into the pixels.

They have been re-exported through `tool/fix_sprite_alpha.py`, which:

- **Alpha-bleeds** the art colour outward into the transparent margin. The GPU
  interpolates RGB and alpha independently, so whatever colour hides under
  transparent pixels gets mixed in at the sprite's edge and when mipmaps are built.
  Padding it with the art's own edge colour removes that as a source of fringing.
- **Normalises** near-opaque alpha to a true 255 (`car_body.png` topped out at 254).

The script asserts that no visible pixel changes — same alpha everywhere, same RGB
wherever alpha is non-zero. Run `python3 tool/fix_sprite_alpha.py --check` to verify
the committed files are clean; it needs `pillow` and `numpy`.

---

## 3. Project structure

```
lib/
├── main.dart                          App shell, GameWidget, overlay wiring
├── game/
│   ├── config.dart                    ★ ALL TUNING CONSTANTS LIVE HERE
│   ├── mars_climb_game.dart           Forge2DGame: camera, run lifecycle, tick
│   ├── level/
│   │   ├── level.dart                 ★ Level definitions (all courses here)
│   │   ├── theme.dart                 ★ Per-course sky/scenery/ground palettes
│   │   ├── level_stats.dart           Memoised grade/relief/profile per course
│   │   ├── finish_line.dart           Checkered banner at the course end
│   │   └── start_wall.dart            Invisible wall behind the start line
│   ├── state/
│   │   └── game_state.dart            ChangeNotifier the HUD listens to
│   ├── terrain/
│   │   ├── noise.dart                 Seeded value noise + fBm (no dependency)
│   │   ├── terrain_generator.dart     surfaceY(x) — single source of truth
│   │   ├── terrain_chunk.dart         One chain-shape body + its ground fill
│   │   └── terrain_manager.dart       Streams chunks in/out, culls, spawns cells
│   ├── vehicle/
│   │   ├── vehicle.dart               ★ Vehicle + WheelMount definitions
│   │   ├── rover.dart                 Chassis body, wheel joints, drive logic
│   │   ├── wheel.dart                 Circle body + spinning tyre sprite
│   │   └── driver_head.dart           Welded head body — the flip detector
│   ├── collectibles/
│   │   └── energy_cell.dart           Sensor pickup, drawn procedurally
│   └── world/
│       └── mars_backdrop.dart         Sky gradient, sun, stars, 3 parallax bands
└── ui/
    ├── machine_select_screen.dart     Step 1: pick a machine (app home)
    ├── course_select_screen.dart      Step 2: pick a course
    ├── vehicle_preview.dart           Chassis with its wheels fitted
    ├── vehicle_stats.dart             Normalised stat bars across the roster
    ├── level_profile.dart             Draws a course's real silhouette
    ├── game_screen.dart               Hosts one run of one course
    ├── hud.dart                       Oxygen, cells, level progress, speed
    ├── controls.dart                  GAS / BRAKE hold-buttons
    └── outcome_overlay.dart           Win + lose panel, run summary
```

## The garage

**19 machines**: five buggies, seven bikes and seven trikes.

A vehicle is one `Vehicle` in `game/vehicle/vehicle.dart` plus two PNGs — a
chassis and a wheel. Every dimension and handling number comes from that
object, so `rover.dart` is the same code for all of them.

Wheels are a `List<WheelMount>` rather than a front/rear pair, so a bike, a
trike and a six-wheeler are all the same code path. Engine torque is split
across the driven wheels — otherwise a six-wheeler would have three times the
shove of a bike from the same engine.

**A trike is a two-axle machine here.** In side view a reverse trike's two
front wheels sit at the same x, so the third wheel is width, not length: it
shows up as grip and stability, not as another mount. Wheel counts above two
only mean extra *axles* — a 6x6 truck, not a trike.

`vehicles_test` checks the assets exist, every wheel sits inside its own body
art and below the chassis centre, no two wheels overlap, something drives the
machine, and no single machine leads every stat — if one did, there would be
no reason to drive the others.

## The courses

| # | Name | Length | Max grade | Relief | Theme | Character |
|---|---|---|---|---|---|---|
| 1 | Acidalia Flats | 520 m | 35° | 9 m | Dusk | Shakedown; rolling dunes |
| 2 | Chryse Ripples | 640 m | 41° | 14 m | Noon | Short choppy ridges, never settles |
| 3 | Tharsis Rollers | 780 m | 40° | 17 m | Dust storm | Long heavy swells, big airtime |
| 4 | Olympus Ascent | 900 m | 47° | 23 m | Night | A genuine mountain |

Terrain is two waves, not one: detail noise for bumps, plus a much longer
`macroScale` wave underneath that produces **sustained climbs**. Without it a
course is only chop, and chop is trivial at speed — you carry momentum straight
over it. `levels_test` measures the steepest *average* grade over 30 m and 60 m
windows and fails if a course has no real climb in it.

`slopeBudget` is measured against the **starter machine's** grip, so 1.0 means
"right at the limit of what a Pathfinder can hold". Grippier machines can go
beyond it; slippier ones cannot. `levels_test` prints which machines can clear
each course and fails if level 1 locks anyone out or any course leaves fewer
than two machines viable.

Every course carries its own `LevelTheme` — sky gradient, three scenery bands,
ground, sun and star density — so no two read as the same place. The one rule a
theme must respect is **atmospheric perspective**: each band steps lighter as it
recedes, and every band stays lighter than the ground. Inverting that is what
once made distant dunes look like a hole in the world.

Adding a course is one `const Level` in `game/level/level.dart` plus an entry
in `levels`. Everything else — terrain, streaming, finish line, level select
card, geometry tests — picks it up automatically.

Each level declares a `slopeBudget`: how steep it is *allowed* to get, as a
fraction of the rover's physical grip ceiling. That is the difficulty dial, and
`levels_test` enforces it, so a course can never quietly become unclimbable.

### Tests

`test/level1_test.dart` checks the *course* rather than the physics: both ends
flat, no cliffs between chain vertices, and no slope steeper than the rover's
grip allows. The steepness budget is derived from `wheelFriction` and
`terrainFriction` rather than hard-coded, so retuning grip automatically
retunes what counts as a fair level. It also prints an ASCII profile:

```
       --      --              --               ### --##             #####   -
       ###    ####-        -# ####-            -########             ######-####
###########  -######      -########        -- -##########           ##############
```

`test/render_preview_test.dart` renders the **real** backdrop and terrain code
to PNGs through the same camera maths the game uses — no device needed:

```bash
flutter test test/render_preview_test.dart --tags preview
# PNGs land in build/previews/
```

It is tagged `preview` and excluded from normal runs (`flutter test
--exclude-tags=preview`) because it writes files instead of asserting. This is
what caught the "cliff" artefact: the terrain was fine, and the hard edge was
the parallax palette.

---

## 4. Tuning

**Everything you'd want to fiddle with is in `lib/game/config.dart`**, grouped and
commented. The headline knobs:

| Constant | What it does |
|---|---|
| `gravity` | `7.2` — between real Mars (3.71) and Earth (9.81). Drop it for floaty airtime. |
| `engineMaxTorque` | Climbing power. |
| `engineMaxMotorSpeed` | Top speed cap (wheel rad/s). |
| `wheelFriction` | **Grip.** The single biggest handling knob. |
| `suspensionFrequencyHz` | Spring rate. ~4 Hz soft buggy, ~9 Hz stiff. |
| `suspensionDampingRatio` | 0 = pogo stick, 1 = critically damped. |
| `chassisPitchTorque` | Nose-lift under throttle — the wheelie. |
| `visibleWorldHeight` | **Zoom.** Metres of world visible vertically — smaller is more zoomed in. |
| `headDensity` | Top-heaviness. The helmet's mass is what makes the rover want to flip. |
| `rolloverRadians` | How much rotation counts as a flip (default a full 360°). |
| `oxygenIdleDrain` / `oxygenThrottleDrain` | How brutal the fuel clock is. |

Per-course settings — length, seed, hill amplitude/wavelength, cell spacing —
live on the `Level` in `game/level/level.dart`, not in `config.dart`.

### If the rover drives backwards

Flip `GameConfig.driveDirection` from `1.0` to `-1.0`. Forge2D's angular sign
convention against Flame's y-down world is easy to get backwards, and this is the
one-line fix rather than a hunt through the joint code.

### Suspension travel is advisory

forge2d 0.13's `WheelJoint` has **no translation limit** — no `enableLimit`,
`lowerTranslation` or `upperTranslation`. The spring is the only thing stopping the
wheel, so `suspensionLowerTranslation` / `suspensionUpperTranslation` in the config
document intent but do not constrain anything. Stiffen the spring to reduce travel.

The joint takes the spring as a `frequencyHz` / `dampingRatio` pair, which is what the
config exposes. Box2D 2.4 and newer forge2d releases want raw `stiffness`/`damping`
instead; if you bump the package and it stops compiling, convert with
`omega = 2*pi*f; stiffness = m*omega^2; damping = 2*m*zeta*omega`.

---

## 5. How the pieces work

**Terrain** is a pure function: `TerrainGenerator.surfaceY(x)` returns the ground
height for any x, from seeded fBm value noise. Chunks, collectible placement and the
rover spawn all query that same function, so nothing can disagree about where the
ground is. `TerrainManager` keeps a window of chunks (`chunksBehind` … `chunksAhead`)
alive around the rover and culls the rest. Each chunk sets Forge2D **ghost vertices**
(`prevVertex` / `nextVertex`) so wheels don't snag on the seam between chunks.

The first `terrainFlatRunway` metres are flat, and hill amplitude smoothstep-ramps
in over `terrainRampDistance`, so the rover always gets a clean start.

**The engine.** The joint motor is a *speed servo*: `motorSpeed` is a setpoint
and `maxMotorTorque` a cap. With a flat cap the machine simply holds its target
speed up any slope it can grip — hills stop mattering and the game plays itself.
So available torque now fades as the wheels spin up:

```
torque = engineMaxTorque * (1 - (spin / maxSpin) ^ powerCurveExponent)
```

Full pull from a standstill, nothing left at the cap. Quadratic drag on the
chassis sets the actual top speed — the machine accelerates until torque meets
drag — so a climb genuinely costs speed and a steep enough grade stalls you.
`powerCurveExponent` is the engine's character: 1.3 is peaky and light, 3.2 is a
big lazy diesel.

**The rover** is a chassis box with two circle wheels on `WheelJoint`s (spring
suspension + motors). Drive is AWD by default — toggle `rearWheelDrive` /
`frontWheelDrive`. Joints are built lazily on the first tick where every body is
mounted, because awaiting sibling mounts inside `onLoad` deadlocks Flame's lifecycle
queue.

**The driver's head** is a real circle body welded to the chassis, colliding with
terrain only (never with its own rover, via collision filtering). Its `beginContact`
is the flip/crash detector.

**Parallax** lives on `camera.backdrop`, which renders in viewport space untouched by
the camera transform — so each band reads the camera position itself and offsets by
its own factor (`0.08` far rim → `0.42` near dunes). Stars drift slowest of all.

**Levels.** A `Level` is a finite course: length, seed, hill shape, cell spacing.
Terrain streams only within `[0, length + runOut]`, and hill amplitude ramps to
zero approaching the finish, so the finish banner always sits on flat, landable
ground. A `StartWall` stops the rover reversing off the back; the far end
deliberately has none, because driving off it is a real way to lose.

**Camera.** Zoom is derived from the real screen height every resize
(`zoom = screenHeight / visibleWorldHeight`), using Flame's default full-screen
viewport. The same slice of world is visible on every device, the scene fills
the display edge to edge, and there are no letterbox bars.

**Ending a run.** One win and four losses:

| Outcome | Trigger |
|---|---|
| Level complete | Rover's x reaches the finish line |
| Oxygen depleted | Fuel cell hits zero |
| Helmet breach | The driver's head body touches terrain |
| Rover flipped | A full 360° roll without recovering, **or** lying inverted past a grace period |
| Lost off-map | Rover falls further below the ground than `fallOutMargin` |

The flip check integrates the chassis' angular velocity while it is tipped and
resets the moment it settles upright, so rocking on a landing never accumulates
into a false positive.

---

## 6. Status

### Verified

Against a real Flutter 3.24.5 SDK:

- `flutter pub get` resolves.
- `flutter analyze` — **No issues found.**
- `flutter build bundle` compiles all Dart and packages all three PNGs.

That shook out several genuine errors in the first draft: an impossible version pin,
`ChainShape.hasPrevVertex`, `Body.getWorldVector`, `WheelJointDef`'s limit fields, and
`createJoint` taking a `Joint` rather than a `JointDef`. See §4 on suspension.

**Sprite placement is measured, not guessed** — wheel anchors, wheel sprite scale,
driver size/offset and head offset were derived by compositing the three PNGs and
checking the result by eye.

### Not verified

- **The APK build itself.** No Android SDK was reachable from the machine this was
  written on, so Gradle/AGP/signing is proven only by CI. Run the workflow (§1) — that
  is what it is for.
- **The game actually playing.** Nothing here has been run on a device or emulator.
  The physics constants (torque, grip, suspension, gravity) are untested starting
  points; expect to spend real time in `config.dart`.
- Whether `driveDirection` needs flipping — see §4.

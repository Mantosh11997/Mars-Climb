# Mars Climb

A Hill-Climb-Racing-style rover game set on Mars, built with **Flutter + Flame + Forge2D**.

---

## 1. Getting it running

This repo contains the Dart source and assets only — no platform folders. Generate them once:

```bash
flutter create . --project-name mars_climb --platforms=android,ios,web
flutter pub get
flutter run
```

`flutter create .` will not overwrite `lib/`, `assets/` or `pubspec.yaml`'s dependency
block, but **do check `pubspec.yaml` afterwards** and re-add the `assets:` section if
it got rewritten.

### Pinned versions

| Package | Version | Note |
|---|---|---|
| `flame` | `1.18.0` | pinned exactly |
| `flame_forge2d` | `0.18.2` | pinned exactly — must match the flame version |
| `forge2d` | `0.13.x` | transitive, via `flame_forge2d` |

`flame` and `flame_forge2d` version-lock to each other. If you bump one, bump the other
from the [flame_forge2d compatibility table](https://pub.dev/packages/flame_forge2d).

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
│   ├── state/
│   │   └── game_state.dart            ChangeNotifier the HUD listens to
│   ├── terrain/
│   │   ├── noise.dart                 Seeded value noise + fBm (no dependency)
│   │   ├── terrain_generator.dart     surfaceY(x) — single source of truth
│   │   ├── terrain_chunk.dart         One chain-shape body + its ground fill
│   │   └── terrain_manager.dart       Streams chunks in/out, culls, spawns cells
│   ├── vehicle/
│   │   ├── rover.dart                 Chassis body, wheel joints, drive logic
│   │   ├── wheel.dart                 Circle body + spinning tyre sprite
│   │   └── driver_head.dart           Welded head body — the flip detector
│   ├── collectibles/
│   │   └── energy_cell.dart           Sensor pickup, drawn procedurally
│   └── world/
│       └── mars_backdrop.dart         Sky gradient, sun, stars, 3 parallax bands
└── ui/
    ├── hud.dart                       Oxygen gauge, cells, distance, speed
    ├── controls.dart                  GAS / BRAKE hold-buttons
    └── game_over_overlay.dart         Run summary + redeploy
```

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
| `terrainAmplitude` / `terrainWavelength` | Hill height / hill length. |
| `terrainSeed` | Change it, get a different planet. |
| `oxygenIdleDrain` / `oxygenThrottleDrain` | How brutal the fuel clock is. |

### If the rover drives backwards

Flip `GameConfig.driveDirection` from `1.0` to `-1.0`. Forge2D's angular sign
convention against Flame's y-down world is easy to get backwards, and this is the
one-line fix rather than a hunt through the joint code.

### If suspension throws a compile error

`WheelJointDef` gained `stiffness`/`damping` (Box2D 2.4 style) in forge2d 0.12.
On older forge2d the fields are `frequencyHz` and `dampingRatio` — set those
straight from the config and delete the conversion block in
`rover.dart :: _attachWheel`.

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

**Lose conditions:** oxygen hits zero, or the driver's head touches the ground.

---

## 6. Status

**Not compiled** — written without a Flutter SDK to hand. Expect to shake out a
couple of API-signature mismatches on the first `flutter run`, most likely around the
`WheelJointDef` suspension fields (see §4) and Forge2D method names.

**Sprite placement is measured, not guessed.** The wheel anchors, wheel sprite scale,
driver size/offset and head offset in `config.dart` were derived by compositing the
three PNGs together and checking the result by eye, so the rover should assemble
correctly on first run. The *physics* constants (torque, grip, suspension, gravity)
are untested starting points and will need real tuning against the running game.

# CI

## `build-apk.yml`

Builds an installable Android APK.

**Triggers:** pushes and PRs against `main` or `claude/**` (markdown-only changes are
skipped), plus manual runs via **Actions → Build APK → Run workflow**, where you can
pick `release`/`debug` and optionally produce per-ABI APKs.

**Getting the APK:** open the run, scroll to **Artifacts**, download
`mars-climb-apk-<run number>`. Kept for 30 days.

### Why it runs `flutter create`

The repo holds only `lib/`, `assets/` and `pubspec.yaml` — there is no committed
`android/` folder. The workflow generates one per run, then restores every tracked
file with `git checkout -- .` so `flutter create` cannot quietly rewrite
`pubspec.yaml` (dropping the pinned Flame versions and the assets block) or
`lib/main.dart`. Only the untracked `android/` tree survives.

It also deletes the template `test/widget_test.dart` that `flutter create` drops in —
it pumps a `MyApp` counter widget this project doesn't have, and left in place it fails
`flutter analyze` with an error unrelated to our code.

If you'd rather commit the platform folder — worth doing once you need a signing
config, custom icons, permissions or a real `applicationId` — run:

```bash
flutter create . --project-name mars_climb --org com.marsclimb --platforms=android
git add android && git commit -m "Add Android platform files"
```

then delete the "Generate Android platform files" step from the workflow.

### Signing

`flutter build apk --release` falls back to the debug keystore, so the APK installs
on any device with "install from unknown sources" enabled. That is fine for testing
and **not** fine for the Play Store — publishing needs a real upload key, an
`android/key.properties`, and the keystore held in GitHub Secrets.

### Version pinning

`FLUTTER_VERSION` is `3.24.5` — the SDK the project was actually verified against
(`pub get`, `analyze`, `build bundle` all clean). It pairs with `flame 1.19.0` /
`flame_forge2d 0.18.2` / `forge2d 0.13.1`. Bump the SDK in step with the packages,
not ahead of them.

`JAVA_VERSION` is `17`, and that is **load-bearing**: the Flutter 3.24.5 Android
template ships Gradle 8.3, which does not support Java 21. On a JDK 21 machine
`flutter create` warns about exactly this. If you bump Flutter, check the template's
`gradle-wrapper.properties` before raising the JDK.

### Heads-up: `git checkout -- .`

The generate step discards all uncommitted changes to tracked files. That is correct in
CI, where the checkout is always clean — but if you run those same commands locally with
work in progress, it will destroy it. The step guards against this by failing if the
working tree is dirty before it starts.

### `flutter analyze` doesn't block the build

It's `continue-on-error: true` on purpose: the analyzer output is the most useful
thing this workflow produces, and letting the build step also run means one push
surfaces both sets of errors instead of one per round trip.

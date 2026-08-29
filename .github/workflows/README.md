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

`FLUTTER_VERSION` is pinned to `3.24.5` to match `flame 1.18.0` /
`flame_forge2d 0.18.2`, which are from the Flutter 3.22–3.24 era. Newer Flutter
releases have broken Flame builds before, so bump the SDK in step with the packages
rather than ahead of them.

### `flutter analyze` doesn't block the build

It's `continue-on-error: true` on purpose: the analyzer output is the most useful
thing this workflow produces, and letting the build step also run means one push
surfaces both sets of errors instead of one per round trip.

# android-kotlin

Dev environment for Android with Kotlin and Jetpack Compose (nixpkgs
androidenv). Ships a single `MainActivity` with a hello-world Compose screen
(Material 3) and one sample unit test — start adding your own code instead of
deleting someone else's.

```bash
nix flake init -t github:Marcus441/nix-templates#android-kotlin
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
gradle assembleDebug
```

Then make it yours:

1. Set `appName` (launcher label) and `appId` (application id / namespace) in
   `gradle.properties` — the single place the app's identity is declared. The
   `app_name` string resource is generated from `appName` at build time.
2. Rename the package to match `appId`: move
   `app/src/main/java/com/example/app` and `app/src/test/java/com/example/app`,
   and update the `package` lines in the `.kt` files.
3. Set the project name in `settings.gradle.kts`.
4. Build your UI in the `App()` composable in `MainActivity.kt`.

## What you get

- JDK 17
- Android SDK: platform-tools, build-tools 35/36, platform 36
- Gradle 8.x (the wrapper `./gradlew` is committed, so a system Gradle is
  optional)
- for emulator testing, an Android system image plus `avdmanager` / `emulator`

The dev shell provides all of these with `ANDROID_HOME`, `ANDROID_SDK_ROOT` and
`JAVA_HOME` set. Dependency and plugin versions are declared in
`gradle/libs.versions.toml` (Gradle version catalog) — bump them there.

This template is `x86_64-linux` only. The `systems` list in `flake.nix` says so,
and the emulator image is built for `x86_64`.

## Setup (non-Nix)

1. Install JDK 17.
2. Install the Android SDK via
   [command-line tools](https://developer.android.com/studio#command-tools) or
   Android Studio's SDK Manager.
3. Set env vars:
   ```bash
   export ANDROID_HOME=/path/to/android-sdk
   export ANDROID_SDK_ROOT=$ANDROID_HOME
   ```
4. Install required packages:
   ```bash
   sdkmanager "platform-tools" "build-tools;36.0.0" "platforms;android-36"
   ```
5. Use `./gradlew` in place of `gradle` in all commands below — the wrapper is
   committed, no system Gradle needed.

## Building

```bash
gradle assembleDebug        # non-Nix: ./gradlew assembleDebug
```

APK output: `app/build/outputs/apk/debug/app-debug.apk`

There is no `nix build` for this template: a Gradle build resolves dependencies
over the network, which a Nix build sandbox does not have.

## Running — physical device

```bash
adb devices
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.example.app/.MainActivity
```

## Running — emulator

```bash
avdmanager create avd -n dev -k "system-images;android-36;google_apis;x86_64"
emulator -avd dev
```

Wait for boot, then install/launch as above:

```bash
adb wait-for-device
adb shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done'
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.example.app/.MainActivity
```

On NixOS/Wayland, if the emulator fails with a Qt platform plugin error:

```bash
QT_QPA_PLATFORM=xcb emulator -avd dev
```

## Dev loop

With a device or emulator connected:

```bash
./dev.sh
```

Watches sources and rebuilds, reinstalls, and relaunches the app on every save
(a few seconds per cycle; app state is lost). For true hot reload with state
preservation, open the project in Android Studio and use Live Edit.

## Testing

```bash
gradle test                  # unit tests, non-Nix: ./gradlew test
gradle connectedAndroidTest  # instrumented tests, needs a device/emulator
```

## CI

GitHub Actions workflow: `.github/workflows/ci.yml`. Two jobs: `./gradlew build`
(assemble + unit tests + lint) and `connectedAndroidTest` on an x86_64 API 34
emulator. Works as-is in a repo created from this template.

## Logs

```bash
adb logcat
```

## Notes

- **`ANDROID_HOME` points straight into the Nix store, and that is fine.**
  Everything here is read from by Gradle, adb, avdmanager and the emulator, and
  never written to, so an immutable path works. `avdmanager` writes AVD configs
  to `~/.android/avd`, outside the SDK tree.
- **Licence acceptance is a nixpkgs config option**, `android_sdk.accept_license`,
  not an argument to `composeAndroidPackages`. It is set inside the flake
  alongside `allowUnfree`, so no `--impure` is needed.
- If you bump a version in `composeAndroidPackages` and it is not in this
  nixpkgs revision's manifest, `nix develop` errors with a message listing the
  versions that *are* available — pick one of those.
- `nix fmt` formats `flake.nix` with alejandra.

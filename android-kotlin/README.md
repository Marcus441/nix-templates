# Android Kotlin Template

Starter for an Android app: Kotlin + Jetpack Compose (Material 3), built with Gradle.
Ships a single `MainActivity` with a hello-world Compose screen and one sample unit
test — start adding your own code instead of deleting someone else's.

## Quick start

```bash
nix develop          # or `direnv allow` if using direnv
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

## Dependencies

- JDK 17
- Android SDK: platform-tools, build-tools 35/36, platform 36
- Gradle 8.x (the wrapper `./gradlew` is committed, so a system Gradle is optional)
- (emulator testing only) an Android system image + `avdmanager`/`emulator`

Dependency and plugin versions are declared in `gradle/libs.versions.toml`
(Gradle version catalog) — bump them there.

The Nix dev shell provides all of these (`gradle`, `kotlin`, `adb`, `avdmanager`,
`emulator`, the SDK) with `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `JAVA_HOME` set.

## Setup (non-Nix)

1. Install JDK 17.
2. Install the Android SDK via [command-line tools](https://developer.android.com/studio#command-tools) or Android Studio's SDK Manager.
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
gradle connectedAndroidTest  # instrumented tests, requires a running device/emulator
```

## CI

GitHub Actions workflow: `.github/workflows/android.yml` (repo root). Two jobs:
`./gradlew build` (assemble + unit tests + lint) and `connectedAndroidTest` on
an x86_64 API 34 emulator. If you start a project from this template, copy the
workflow into your repo and drop the `paths` filters and `working-directory`
settings.

## Logs

```bash
adb logcat
```

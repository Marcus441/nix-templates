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

1. Pick your application id and rename the package: replace `com.example.app` in
   `app/build.gradle.kts` (`namespace`, `applicationId`), move
   `app/src/main/java/com/example/app` and `app/src/test/java/com/example/app`
   to match, and update the `package` lines in the `.kt` files.
2. Set the app name in `app/src/main/res/values/strings.xml`.
3. Set the project name in `settings.gradle.kts`.
4. Build your UI in the `App()` composable in `MainActivity.kt`.

## Dependencies

- JDK 17
- Android SDK: platform-tools, build-tools 34.0.0, platforms 33/34
- Gradle 8.x
- (emulator testing only) an Android system image + `avdmanager`/`emulator`

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
   sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34" "platforms;android-33"
   ```
5. Generate the Gradle wrapper (one-time, requires a system Gradle install):
   ```bash
   gradle wrapper --gradle-version 8.14
   ```
   Use `./gradlew` in place of `gradle` in all commands below.

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
avdmanager create avd -n dev -k "system-images;android-34;google_apis;x86_64"
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

## Testing

```bash
gradle test                  # unit tests, non-Nix: ./gradlew test
gradle connectedAndroidTest  # instrumented tests, requires a running device/emulator
```

## Logs

```bash
adb logcat
```

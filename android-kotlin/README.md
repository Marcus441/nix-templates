# Todo (Android Kotlin)

Minimal Android todo app: Kotlin + Jetpack Compose, built with Gradle.

## Dependencies

- JDK 17
- Android SDK: platform-tools, build-tools 34.0.0, platforms 33/34
- Gradle 8.7
- (emulator testing only) an Android system image + `avdmanager`/`emulator`

## Setup (Nix)

```bash
nix develop
```

Provides `gradle`, `kotlin`, `adb`, `avdmanager`, `emulator`, and the SDK, with
`ANDROID_HOME`, `ANDROID_SDK_ROOT`, `JAVA_HOME` set.

*(`direnv allow` if using direnv)*

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
   gradle wrapper --gradle-version 8.7
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
adb shell am start -n com.example.todo/.MainActivity
```

## Running — emulator

```bash
avdmanager create avd -n todo-test -k "system-images;android-34;google_apis;x86_64"
emulator -avd todo-test
```

Wait for boot, then install/launch as above:

```bash
adb wait-for-device
adb shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done'
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.example.todo/.MainActivity
```

On NixOS/Wayland, if the emulator fails with a Qt platform plugin error:

```bash
QT_QPA_PLATFORM=xcb emulator -avd todo-test
```

## Testing

```bash
gradle test                 # unit tests, non-Nix: ./gradlew test
gradle connectedAndroidTest  # instrumented tests, requires a running device/emulator
```

## Logs

```bash
adb logcat
```

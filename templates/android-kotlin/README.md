# android-kotlin

Dev environment for Android with Kotlin, Jetpack Compose and Google's Android
CLI. This template ships **no project** — it pins the toolchain and lets
`android create` generate the app, so the Gradle, AGP and Compose versions you
start from are Google's current ones rather than whatever was current when this
template was written.

```bash
nix flake init -t 'github:Marcus441/nix-templates#android-kotlin'
git init && git add -A          # flakes see only tracked files
nix develop                     # or: direnv allow
android create --name="My App" -o myapp
cd myapp && gradle assembleDebug
```

`android create` **refuses a non-empty directory**, so the project goes in a
subdirectory rather than beside `flake.nix`. Everything below runs from inside
that subdirectory unless it says otherwise.

Then one edit to finish the setup:

- **Set `PROJECT_DIR` in `.github/workflows/ci.yml`** to the directory you just
  passed to `-o`. It ships as `myapp`; if you chose another name, CI builds a
  path that does not exist. This template cannot know the name you picked —
  it is the one thing `android create` does not fill in for you.

## What you get

- `android` — Google's Android CLI: scaffolding, SDK, emulators, deploy,
  UI inspection, and a bridge into a running Android Studio
- JDK 17 — what the generated project asks for via `jvmToolchain(17)`
- Gradle 9.5.1 — AGP 9 requires Gradle 9.1.0 or newer
- `kotlinc` for scratch files, and `ktlint`

The SDK itself is **not** in this flake; see [The SDK is yours](#the-sdk-is-yours).

## Scaffolding

```bash
android create --list --name=x        # the template menu
android create --name="My App" -o myapp
android create --name="My App" -o myapp --minSdk=26
```

Today there is exactly one template, `empty-activity` (the default), tagged
`compose,activity,agp-9`. It generates a great deal more than a hello-world:
AGP 9, Kotlin 2.3, a Compose BOM, Material 3 theme files, launcher icons,
Navigation 3, a ViewModel with a repository, a unit test and a Compose UI test.

`--name` sets the application name, the package (`com.example.myapp`) and
`rootProject.name` in one go — there is no package to rename by hand afterwards.

Two things `android create` does for you that are worth knowing about:

- it installs any SDK package it needs (`platforms/android-36`, the project
  templates themselves) into your SDK;
- it writes `local.properties` with `sdk.dir=…`, which is how Gradle finds the
  SDK. That file is gitignored and machine-local, so a fresh clone of your
  project needs `ANDROID_HOME` set or its own `local.properties`.

## Building

```bash
gradle assembleDebug        # or ./gradlew assembleDebug
gradle test                 # unit tests
gradle connectedAndroidTest # instrumented tests, needs a device or emulator
```

The generated wrapper pins Gradle 9.1.0; the shell's `gradle` is 9.5.1 and
satisfies AGP 9 the same way, without downloading a second distribution. Use
`./gradlew` if you want the pinned one.

APK path: `app/build/outputs/apk/debug/app-debug.apk`, or ask for it —

```bash
android describe
```

which prints every variant's APK path and whether it exists yet. `android
describe` shells out to `./gradlew`, so run it from inside the dev shell;
outside it there is no JDK and it fails with `gradlew failed with exit code 1`.

There is no `nix build` for this template: a Gradle build resolves dependencies
over the network, which a Nix build sandbox does not have.

## Emulator

```bash
android emulator create --list-profiles
android emulator create medium_phone     # profile is positional
android emulator list
android emulator start medium_phone      # returns once it is ready to use
android emulator start medium_phone --cold
android emulator stop emulator-5554
android emulator remove medium_phone
```

`android emulator start` blocks until the device is actually usable, which
replaces the usual `adb wait-for-device` plus `getprop sys.boot_completed` loop.

## Deploy and inspect

```bash
android run --apks=app/build/outputs/apk/debug/app-debug.apk
android run --apks=base.apk,split.apk --device=emulator-5554
android run --apks=app-debug.apk --debug
```

`android run` installs and launches in one step; it does **not** build, so
`gradle assembleDebug` comes first. Add `--activity` if the APK has more than
one launchable activity.

For looking at what is on screen without an IDE:

```bash
android layout --pretty                       # UI tree as JSON
android layout --diff                         # only what changed since last call
android screen capture --output=ui.png
android screen capture --annotate -o ui.png   # labelled boxes on UI elements
android screen resolve --screenshot=ui.png --string="input tap #5"
```

`screen resolve` turns a label from an annotated screenshot into real
coordinates, so a tap can be scripted without measuring pixels.

## Neovim and the official Kotlin LSP

The dev shell deliberately does **not** ship a language server — bring your own,
and it will work provided:

1. **Scaffold first, then open the editor.** The server roots on
   `settings.gradle.kts` / `build.gradle.kts`, which do not exist until
   `android create` has run. Open the editor at the project root (`myapp/`),
   not at the flake root.
2. **Launch the editor from inside the shell,** or let direnv put you there.
   The server imports the Gradle model as a subprocess and needs `JAVA_HOME`
   and a `gradle` on `$PATH`; an editor started from your desktop session has
   neither.
3. **Build once before expecting resolution.** There is no Gradle model to
   import until a build has produced one.

Two caveats worth knowing before you debug your config:

- JetBrains describes Android Gradle Plugin support in the Kotlin LSP as
  **experimental**. A symbol that will not resolve in an Android source set is
  as likely to be that as it is to be your setup.
- nixpkgs has no `kotlin-lsp` package — `kotlin-language-server` is the older
  community server, not JetBrains'. JetBrains publishes the official one only
  as a per-platform archive on its own CDN.

`ktlint` is on `$PATH` for linting and formatting. The official server also
advertises formatting, which is IntelliJ's own Kotlin formatter and generally
the better choice if your editor can use it.

## Android Studio

The CLI drives a **running** Studio instance, which is what makes this template
serve both workflows rather than picking one. Start with:

```bash
android studio check      # PIDs and open projects; run this first
```

then, against that instance:

```bash
android studio render-compose-preview \
  --output-image-file=preview.png --print-semantics \
  app/src/main/java/com/example/myapp/ui/main/MainScreen.kt MainScreenPreview
android studio analyze-file app/src/main/java/com/example/myapp/MainActivity.kt
android studio find-declaration --short MainScreen
android studio find-usages --short MainScreen
android studio open-file app/src/main/java/com/example/myapp/Navigation.kt
android studio version-lookup androidx.compose.ui:ui agp kotlin
```

`render-compose-preview` is the terminal substitute for the Compose Preview
pane, and `analyze-file` runs the IDE's own inspections rather than a separate
linter. Both need Studio open on the project.

## Agents

```bash
android docs search 'how do I handle configuration changes'
android docs fetch kb://android/topic/performance/overview
android skills list --long
android skills add --all
android init                 # installs the android-cli skill for detected agents
```

## The SDK is yours

This flake pins the toolchain — JDK, Gradle, Kotlin, ktlint, the CLI — and
leaves the Android SDK to you and to `android`. That is not an oversight:
`android create` installs SDK packages as it runs, so it needs a **writable**
SDK, which a Nix store path is not.

```bash
android info                            # where it thinks the SDK is
android sdk list 'platforms*'
android sdk list --all 'build-tools*'
android sdk install platforms/android-36 build-tools/36.0.0 platform-tools
android sdk install --canary system-images/android-36/google_apis/x86_64
android sdk update
android sdk remove build-tools/35.0.0
```

With no configuration the CLI uses `~/Android/Sdk`, which is also where Android
Studio puts it — so if you have Studio installed, you already have the SDK and
there is nothing to do. To point somewhere else, set `ANDROID_HOME`, or write
the flag into `~/.androidrc`:

```bash
echo "--sdk=$HOME/Android/Sdk" > ~/.androidrc
```

Three variables split the job, and they are not interchangeable:

| Variable | Default | What it holds |
| --- | --- | --- |
| `ANDROID_HOME` | `~/Android/Sdk` | the SDK itself |
| `ANDROID_USER_HOME` | `~/.android` | CLI state, and the CLI unpacks itself into `$ANDROID_USER_HOME/cli` |
| `ANDROID_AVD_HOME` | `$ANDROID_USER_HOME/avd` | AVDs — and the only one of the three the emulator binary reads |

The dev shell sets `ANDROID_AVD_HOME` from the other two; see
[Notes](#notes) for why it has to.

## Setup (non-Nix)

1. Install JDK 17.
2. Download the Android CLI from
   [d.android.com/tools/agents](https://developer.android.com/tools/agents) and
   put `android` on your `$PATH`.
3. `android sdk install platforms/android-36 build-tools/36.0.0 platform-tools`
4. Use `./gradlew` in place of `gradle` — the generated project commits a
   wrapper, so no system Gradle is needed.

## CI

`.github/workflows/ci.yml` runs `./gradlew build`, the unit tests and lint in
one job, and the instrumented tests on an API 36 emulator in another. It works
as-is once you have scaffolded a project and set `PROJECT_DIR` at the top of the
workflow, as above.

## Notes

- **This template is `x86_64-linux` only.** The `systems` list in `flake.nix`
  says so. nixpkgs builds `android-cli` for `x86_64-linux` and `aarch64-darwin`
  and not for `aarch64-linux`, and only the first is tested here.
- **On NixOS you need `programs.nix-ld.enable = true`.** The SDK packages
  `android sdk install` downloads are Google's own prebuilt FHS binaries, and
  without nix-ld's dynamic loader they do not run at all. With it, `adb`,
  `aapt2` and the build tools work as shipped. The emulator additionally wants
  X11 libraries — add them to `programs.nix-ld.libraries` if it fails on a
  missing `libX11.so.6`, and on Wayland try `QT_QPA_PLATFORM=xcb`.
- **`JAVA_HOME` is `pkgs.jdk17.home`, not `"${pkgs.jdk17}"`.** Only the former
  contains the `release` file that Gradle reads to identify a toolchain. With
  the latter, the generated project's `jvmToolchain(17)` finds no local match
  and the foojay resolver downloads a whole JDK over the network.
- **`android update` cannot work here.** It self-updates the binary in place,
  and the binary lives in the read-only Nix store. It will tell you a newer
  version exists; the way to take it is to bump nixpkgs. Everything else works
  at whatever version nixpkgs carries.
- **The CLI reports usage data to Google by default** — commands, subcommands
  and flag names, not their values. `--no-metrics` turns it off, per-invocation
  or once in `~/.androidrc`.
- **First run writes to `$HOME`.** It unpacks an embedded installation into
  `~/.android` and prints the terms of service and the metrics notice once. It
  does not block on input, so it is safe in scripts and CI.
- **`ANDROID_USER_HOME` does not relocate AVD lookup,** which is why the dev
  shell sets `ANDROID_AVD_HOME`. `android emulator create` writes to
  `$ANDROID_USER_HOME/avd`, but the emulator binary has never heard of that
  variable — it searches `ANDROID_AVD_HOME`, then `ANDROID_SDK_HOME/avd`, then
  `~/.android/avd`. Relocate `ANDROID_USER_HOME` on its own and the emulator
  reports `Unknown AVD name` for a device that is visibly on disk. The shell's
  export derives from whatever you have set, so it is a no-op on a stock setup
  and defers to an explicit `ANDROID_AVD_HOME`.
- **`ANDROID_SDK_ROOT` is ignored** by the CLI; only `ANDROID_HOME` is read.
  Gradle still honours both, and `local.properties` beats either.
- `nix fmt` formats `flake.nix` with alejandra.

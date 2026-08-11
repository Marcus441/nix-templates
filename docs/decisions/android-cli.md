# android-kotlin ships no project, and does not pin the Android SDK

**Why:** Google's Android CLI reached 1.0 in May 2026 and is in nixpkgs as
`android-cli`. `android create` generates an Android project from an official
template, currently `empty-activity` — AGP 9, Kotlin 2.3, a Compose BOM,
Material 3, Navigation 3, a ViewModel over a repository, a unit test and a
Compose UI test — and Google keeps that template current. This repo cannot.

The old template proved the point. It shipped AGP 8.11.1, Compose BOM
2025.06.01, an explicit `org.jetbrains.kotlin.android` plugin and a wrapper
pinned to Gradle 8.14.4. By the time it was replaced, AGP 9 had been out for
seven months, required Gradle 9.1.0, and had absorbed Kotlin support so that
plugin line was wrong rather than merely old. None of it was caught, because at
`tier = "eval"` the harness never built the project — a template's version
catalog ages against nothing at all.

So the split is: this repo owns the *environment*, Google owns the *project*.
`dotnet/` already had that shape, deferring to `dotnet new`; `android-kotlin` is
the second instance, not a new idea.

**The SDK is not pinned, and this is forced rather than chosen.** `android
create` installs SDK packages while it runs — the project templates themselves,
and `platforms/android-36` on demand — so it needs a *writable* SDK. Pointed at
an `androidenv` store path it fails:

```
ERROR: Error downloading sdk package build/templates:
  /nix/store/…-androidsdk/libexec/android-sdk/.sdk: Read-only file system
ERROR: Unknown template name 'empty-activity'
```

There is no flag that avoids this; the templates arrive *as an SDK package*.
Since the whole template is built around `android create`, the SDK belongs to
the developer. Nothing is lost on the Gradle side: `android create` writes
`local.properties` with `sdk.dir=`, which is how Gradle locates the SDK, so no
`ANDROID_HOME` export is needed for a build either.

What the flake still pins is everything that decides whether a build works:
`jdk17`, `gradle_9`, `kotlin`, `ktlint`, `android-cli`. Note this was never a
hermetic build in the first place — a Gradle run resolves hundreds of Maven
artifacts over the network — so pinning the SDK bought consistency, not
reproducibility, and it cost the one command the template exists to run.

**Breaks:** on NixOS the developer needs `programs.nix-ld.enable = true`. The
packages `android sdk install` downloads are Google's own prebuilt FHS binaries,
and patching them is exactly what `androidenv` was for. With nix-ld they run as
shipped — verified for `adb` and for the `aapt2` an AGP 9 build invokes. The
emulator additionally wants X11 on `programs.nix-ld.libraries`. This is a real
cost transferred to the consumer, and the README states it rather than leaving it
to be discovered.

Two smaller consequences. `android update` cannot work, because it rewrites the
binary in place and the binary is in the store; the CLI will report a newer
version and the way to take it is to bump nixpkgs. And `android sdk install`
means the SDK drifts on its own schedule, which the weekly cron cannot speak
for — but the cron never covered the SDK's *contents* anyway, only that the
flake evaluated.

**Also:** the tier rose `eval` → `shell` in the same change. `eval` had been
justified by the multi-GB `androidenv` closure, and with that gone the objection
went with it. It mattered: at `eval`, CI proved nothing whatsoever about a
template whose entire content is a devShell. `android --version` is safe as a
smoke command — it exits 0 on a fresh `HOME` and does not block on the
terms-of-service prompt, though it does unpack into `~/.android` on first run.

`systems` stays `["x86_64-linux"]` and now has two independent reasons: nixpkgs
builds `android-cli` for `x86_64-linux` and `aarch64-darwin` only, so
`aarch64-linux` could not be claimed even if a Gradle build did not need network.

**Rejected: keeping `androidenv` and overriding `ANDROID_HOME` just to
scaffold.** `ANDROID_HOME="$PWD/.android-sdk" android create …`, then build
against the store SDK. It works, but it puts a wart on the first command a reader
runs, leaves two SDK locations to reason about, and duplicates in the store an
SDK most Android developers already have on disk from Studio.

**Rejected: a `shellHook` that copies the store SDK somewhere writable.** Real
work, so the no-banner rule would permit it — but it is multi-GB of copying per
project to reach a state `android sdk install` produces directly.

**Rejected: vendoring `kotlin-lsp` into the template's flake.** nixpkgs has no
`kotlin-lsp` (`kotlin-language-server` is the older community server), so
shipping the official one means a `fetchurl` from JetBrains' CDN plus
`autoPatchelfHook` and an `autoPatchelfIgnoreMissingDeps` soname list — roughly
thirty lines, a second version pin, and a load-bearing rationale that cannot live
in the flake because comments are banned there. The template instead ships
`ktlint` and documents what any Kotlin server needs from the project: a
`settings.gradle.kts` root marker, `JAVA_HOME` and `gradle` inherited from the
shell, and one build so a Gradle model exists to import.

**Rejected: deleting the shipped `.github/workflows/ci.yml`.** It is the one
thing `android create` does not generate. It survives with a `PROJECT_DIR` the
consumer sets, because `android create` refuses a non-empty directory and so the
project cannot sit beside `flake.nix`.

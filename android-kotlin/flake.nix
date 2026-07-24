{
  description = "Android Kotlin development environment (nixpkgs-only, no Android CLI)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          # License acceptance is a nixpkgs config option, not an argument to
          # composeAndroidPackages.
          android_sdk.accept_license = true;
        };
      };

      # Everything here is READ from by Gradle/adb/avdmanager/emulator, never
      # written to -- so an immutable Nix store path works fine. If you bump
      # any version here and it's not in this nixpkgs revision's manifest,
      # `nix develop` will error with a message listing the versions that
      # ARE available -- swap in one of those.
      androidComposition = pkgs.androidenv.composeAndroidPackages {
        cmdLineToolsVersion = "11.0";
        toolsVersion = "26.1.1";
        platformToolsVersion = "36.0.0";
        buildToolsVersions = ["34.0.0"];
        platformVersions = ["33" "34"];
        includeEmulator = true;
        emulatorVersion = "37.1.7";
        includeSystemImages = true;
        systemImageTypes = ["google_apis"];
        abiVersions = ["x86_64"];
        includeNDK = true;
        ndkVersions = ["26.1.10909125"];
        cmakeVersions = ["3.22.1"];
        useGoogleAPIs = true;
      };

      androidSdk = androidComposition.androidsdk;
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = [
          androidSdk
          pkgs.jdk17
          pkgs.kotlin
          pkgs.gradle
        ];

        # Safe to point straight at the Nix store: nothing in this workflow
        # writes into the SDK directory. avdmanager writes AVD configs to
        # ~/.android/avd (outside the SDK tree) and Gradle only reads.
        ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
        ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
        JAVA_HOME = "${pkgs.jdk17}";

        shellHook = ''
          echo "Android Kotlin dev shell (nixpkgs androidenv, CLI-free)"
          echo "ANDROID_HOME=$ANDROID_HOME"
          echo "JAVA_HOME=$JAVA_HOME"
          echo "kotlin: $(kotlin -version 2>&1)"
          echo "gradle: $(gradle -version | grep Gradle)"
        '';
      };
    });
}

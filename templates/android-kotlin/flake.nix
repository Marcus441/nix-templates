{
  description = "Dev environment for Android with Kotlin and Jetpack Compose (nixpkgs androidenv)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs, ...}: let
    systems = ["x86_64-linux"];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (
        system:
          f (import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              android_sdk.accept_license = true;
            };
          })
      );
  in {
    devShells = forAllSystems (pkgs: let
      androidSdk =
        (pkgs.androidenv.composeAndroidPackages {
          cmdLineToolsVersion = "11.0";
          toolsVersion = null;
          platformToolsVersion = "36.0.0";
          buildToolsVersions = ["35.0.0" "36.0.0"];
          platformVersions = ["36"];
          includeEmulator = true;
          emulatorVersion = "37.1.7";
          includeSystemImages = true;
          systemImageTypes = ["google_apis"];
          abiVersions = ["x86_64"];
          includeCmake = false;
          useGoogleAPIs = true;
        })
        .androidsdk;
    in {
      default = pkgs.mkShellNoCC {
        name = "android-kotlin";
        packages = [
          androidSdk
          pkgs.jdk17
          pkgs.kotlin
          pkgs.gradle
        ];
        env = {
          ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
          ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
          JAVA_HOME = "${pkgs.jdk17}";
        };
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}

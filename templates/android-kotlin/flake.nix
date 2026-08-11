{
  description = "Dev environment for Android with Kotlin, Jetpack Compose and Google's Android CLI";

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
            config.allowUnfree = true;
          })
      );
  in {
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShellNoCC {
        name = "android-kotlin";
        packages = [
          pkgs.android-cli
          pkgs.jdk17
          pkgs.gradle_9
          pkgs.kotlin
          pkgs.ktlint
        ];
        env.JAVA_HOME = pkgs.jdk17.home;
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}

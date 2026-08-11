{
  description = "Dev environment for Node.js";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs, ...}: let
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (
        system: f (import nixpkgs {inherit system;})
      );
  in {
    packages = forAllSystems (pkgs: {
      default = pkgs.buildNpmPackage {
        pname = "my-project";
        version = "1.0.0";
        src = ./.;

        nodejs = pkgs.nodejs_24;
        npmDepsHash = "sha256-pOSESMHS1LX9xedM38z5zgRK64ERGaJqgg/eKfap5p0=";
        npmBuildScript = "build";
      };
    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShellNoCC {
        name = "node";
        packages = [pkgs.nodejs_24];
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}

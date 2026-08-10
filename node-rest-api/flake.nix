{
  description = "Dev environment for a Node.js REST API";

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
        npmDepsHash = "sha256-8Gn3KfBLwzYj/dG3trcq/KuQKd+9NtE8MGn6nA0EJFM=";
        npmBuildScript = "build";
      };
    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShellNoCC {
        name = "node-rest-api";
        packages = [pkgs.nodejs_24];
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}

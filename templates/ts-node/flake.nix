{
  description = "Dev environment for Node.js with TypeScript";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs, ...}: let
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (
        system: f (import nixpkgs {inherit system;})
      );

    manifest = builtins.fromJSON (builtins.readFile ./package.json);
  in {
    packages = forAllSystems (pkgs: {
      default = pkgs.buildNpmPackage {
        pname = manifest.name;
        inherit (manifest) version;
        src = ./.;

        nodejs = pkgs.nodejs_24;
        npmDepsHash = "sha256-6wiIwE/GC1TS1v8+YYQo2ySoyvEH5QgBOq7ZooFfPNI=";

        doCheck = true;
        checkPhase = ''
          runHook preCheck
          npm run test
          runHook postCheck
        '';
      };
    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShellNoCC {
        name = "ts-node";
        packages = [pkgs.nodejs_24];
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}

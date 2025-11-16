{
  description = "Jetson C++ flake with g2o + Ceres";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix2container.url = "github:nlewo/nix2container";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nix2container,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        nix2containerPkgs = nix2container.packages.${system};
        pkgsArm = pkgs.pkgsCross.aarch64-multiplatform;
        python = pkgs.python313;
        pythonPkgs = pkgs.python313Packages;
      in {
        devShells.default = pkgs.mkShell {
          name = "jetson-python";

          packages = [
            python
            pythonPkgs.pip
            pythonPkgs.setuptools
            pythonPkgs.wheel

            pythonPkgs.numpy
            pythonPkgs.opencv4
            pythonPkgs.pyyaml

            pkgs.cmake
            pkgs.pkg-config
          ];

          shellHook = ''
            echo "╔═══════════════════════════════════════╗"
            echo "║    Jetson Python Development Shell    ║"
            echo "╚═══════════════════════════════════════╝"
            echo -n " Python: "
            python3 --version
            echo -n " System: "
            uname -m
          '';
        };

        packages.arm64.app = pkgsArm.python311Packages.buildPythonApplication {
          pname = "jetson-python-app";
          version = "0.1.0";
          src = ./.;

          format = "pyproject";

          propagatedBuildInputs = with pkgsArm.python311Packages; [
            numpy
            opencv4
            pyyaml
          ];
        };

        packages.container = let
          l4t-base = nix2containerPkgs.nix2container.pullImage {
            imageName = "nvcr.io/nvidia/l4t-base";
            imageDigest = "sha256:4646e1dd2f26e8de5f2f8776bb02a403bef0148fd7e4d860f836bb858fc5b1cd";
            sha256 = "sha256-snLOWzQsQKS67AfO94j/Cpstr1qVxCvRMQPgMf6SikY=";
            arch = "aarch64-linux";
          };
        in
          nix2containerPkgs.nix2container.buildImage {
            name = "jetson-python-container";

            fromImage = l4t-base;

            copyToRoot = [
              self.packages.${system}.arm64.app
            ];

            config = {
              WorkingDir = "/app";
              Cmd = ["/app/bin/jetson-python-app"];
            };
          };
      }
    );
}

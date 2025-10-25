{
  description = "Jetson C++ flake with g2o + Ceres";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Cross-compilation set for ARM64
      pkgsArm = import nixpkgs {
        crossSystem = {config = "aarch64-unknown-linux-gnu";};
        config.allowUnfree = true;
      };
    in {
      devShells.default = pkgs.mkShell {
        name = "jetson-C++";

        packages = [
          pkgs.gcc
          pkgs.eigen
          pkgs.g2o.dev
          pkgs.ceres.dev
        ];

        shellHook = ''
          echo "╔═════════════════════════════════╗"
          echo "║   Jetson C++ Development Shell    ║"
          echo "╚═════════════════════════════════╝"
        '';
      };

      packages.arm64.app = pkgsArm.stdenv.mkDerivation {
        name = "my-jetson-bin";
        src = ./.;

        buildInputs = [
          pkgsArm.g2o
          pkgsArm.ceres
          pkgsArm.eigen
          pkgsArm.cudaPackages.cudnn
          pkgsArm.cmake
        ];

        buildPhase = ''
          mkdir -p build
          cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
          cmake --build build
        '';
        installPhase = ''
          cmake --install build --prefix $out
        '';
      };

      packages.container = pkgs.dockerTools.buildImage {
        name = "my-jetson-container";
        fromImage = "nvcr.io/nvidia/l4t-base:r32.4.3";

        copyToRoot = [
          self.packages.arm64.app
          pkgs.pkgsCross.aarch64-multiplatform.g2o.out
          pkgs.pkgsCross.aarch64-multiplatform.ceres.out
        ];

        config = {
          WorkingDir = "/app";
          Cmd = ["/app/bin/jetson-bin"];
          Env = [
            "LD_LIBRARY_PATH=/usr/lib:/lib:${pkgs.pkgsCross.aarch64-multiplatform.g2o}/lib:${pkgs.pkgsCross.aarch64-multiplatform.ceres}/lib"
          ];
        };
      };
    });
}

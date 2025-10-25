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
        # Current system packages
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        nix2containerPkgs = nix2container.packages.${system};
        pkgsArm = pkgs.pkgsCross.aarch64-multiplatform;
      in {
        devShells.default = pkgs.mkShell {
          name = "jetson-C++";

          packages = with pkgs; [
            gcc
            cmake
            eigen
            ceres-solver.dev
          ];

          shellHook = ''
            echo "╔══════════════════════════════════╗"
            echo "║   Jetson C++ Development Shell   ║"
            echo "╚══════════════════════════════════╝"
          '';
        };

        packages.arm64.app = pkgsArm.stdenv.mkDerivation {
          name = "jetson-bin";
          src = ./.;

          nativeBuildInputs = with pkgs; [
            cmake
            pkg-config
          ];

          buildInputs = with pkgsArm; [
            gcc
            suitesparse
            blas
            lapack
            eigen
            ceres-solver
          ];

          cmakeFlags =
            /*
            with pkgsArm;
            */
            [
              "-DCMAKE_BUILD_TYPE=Release"
              "-DBUILD_TESTING=OFF"
              # "-DBLAS_LIBRARIES=${blas}/lib/libblas.so"
              # "-DLAPACK_LIBRARIES=${lapack}/lib/liblapack.so"
              # "-DSUITESPARSE_INCLUDE_DIR=${suitesparse}/include"
              # "-DSUITESPARSE_LIBRARY_DIR=${suitesparse}/lib"
              # "-Dnvpl_FOUND=FALSE"
            ];

          cmakeBuildDir = "build";

          cmakeConfigureFlags = ["-S" "." "-B" "build"];
        };

        packages.container = let
          l4t-base = nix2containerPkgs.nix2container.pullImage {
            imageName = "nvcr.io/nvidia/l4t-base";
            imageDigest = "sha256:4646e1dd2f26e8de5f2f8776bb02a403bef0148fd7e4d860f836bb858fc5b1cd";
            sha256 = "sha256-snLOWzQsQKS67AfO94j/Cpstr1qVxCvRMQPgMf6SikY=";
            arch = "aarch64-linux"; # ARM64
          };
        in
          nix2containerPkgs.nix2container.buildImage
          {
            name = "jetson-container";

            fromImage = l4t-base;

            copyToRoot = [self.packages.${system}.arm64.app];

            config = {
              WorkingDir = "/app";
              Cmd = ["/app/bin/jetson-bin"];
            };
          };
      }
    );
}

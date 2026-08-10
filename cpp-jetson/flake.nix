{
  description = "Dev environment for C/C++ on the Jetson platform";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nix2container,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (
        system:
          f (import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          })
      );
  in {
    packages = forAllSystems (pkgs: let
      pkgsArm = pkgs.pkgsCross.aarch64-multiplatform;
      inherit (nix2container.packages.${pkgs.system}) nix2container;

      l4t-base = nix2container.pullImage {
        imageName = "nvcr.io/nvidia/l4t-base";
        imageDigest = "sha256:4646e1dd2f26e8de5f2f8776bb02a403bef0148fd7e4d860f836bb858fc5b1cd";
        sha256 = "sha256-snLOWzQsQKS67AfO94j/Cpstr1qVxCvRMQPgMf6SikY=";
        arch = "aarch64-linux";
      };
    in {
      arm64.app = pkgsArm.stdenv.mkDerivation {
        pname = "jetson-bin";
        version = "0.1.0";
        src = ./.;

        nativeBuildInputs = [
          pkgs.cmake
          pkgs.pkg-config
        ];

        buildInputs = [
          pkgsArm.suitesparse
          pkgsArm.blas
          pkgsArm.lapack
          pkgsArm.eigen
          pkgsArm.ceres-solver
        ];

        cmakeFlags = [
          "-DCMAKE_BUILD_TYPE=Release"
          "-DBUILD_TESTING=OFF"
        ];

        meta.mainProgram = "jetson-bin";
      };

      container = nix2container.buildImage {
        name = "jetson-container";
        fromImage = l4t-base;
        copyToRoot = [self.packages.${pkgs.system}.arm64.app];
        config = {
          WorkingDir = "/app";
          Cmd = ["/app/bin/jetson-bin"];
        };
      };
    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        name = "cpp-jetson";
        packages = [
          pkgs.gcc
          pkgs.cmake
          pkgs.eigen
          pkgs.ceres-solver.dev
        ];
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}

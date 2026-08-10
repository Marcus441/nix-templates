{
  description = "Dev environment for Python on the Jetson platform";

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
      pythonArmPkgs = pkgsArm.python313Packages;
      n2c = nix2container.packages.${pkgs.system}.nix2container;

      l4t-base = n2c.pullImage {
        imageName = "nvcr.io/nvidia/l4t-base";
        imageDigest = "sha256:4646e1dd2f26e8de5f2f8776bb02a403bef0148fd7e4d860f836bb858fc5b1cd";
        sha256 = "sha256-snLOWzQsQKS67AfO94j/Cpstr1qVxCvRMQPgMf6SikY=";
        arch = "aarch64-linux";
      };
    in {
      app-aarch64 = pythonArmPkgs.buildPythonApplication {
        pname = "jetson-python-app";
        version = "0.1.0";
        src = ./.;

        format = "pyproject";

        propagatedBuildInputs = [
          pythonArmPkgs.numpy
          pythonArmPkgs.opencv4
          pythonArmPkgs.pyyaml
        ];

        meta.mainProgram = "jetson-python-app";
      };

      container = n2c.buildImage {
        name = "jetson-python-container";
        fromImage = l4t-base;
        copyToRoot = [self.packages.${pkgs.system}.app-aarch64];
        config = {
          WorkingDir = "/app";
          Cmd = ["/app/bin/jetson-python-app"];
        };
      };
    });

    devShells = forAllSystems (pkgs: let
      pythonPkgs = pkgs.python313Packages;
    in {
      default = pkgs.mkShell {
        name = "python-jetson";
        packages = [
          pkgs.python313
          pythonPkgs.pip
          pythonPkgs.setuptools
          pythonPkgs.wheel
          pythonPkgs.numpy
          pythonPkgs.pyyaml
        ];
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}

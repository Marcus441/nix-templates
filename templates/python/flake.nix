{
  description = "Dev environment for Python with uv, ruff and mypy";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs, ...}: let
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (
        system: f (import nixpkgs {inherit system;})
      );

    project = (builtins.fromTOML (builtins.readFile ./pyproject.toml)).project;
  in {
    packages = forAllSystems (pkgs: {
      default = pkgs.python3Packages.buildPythonApplication {
        pname = project.name;
        inherit (project) version;
        src = ./.;
        pyproject = true;

        build-system = [pkgs.python3Packages.hatchling];
        dependencies = [];

        nativeCheckInputs = [
          pkgs.python3Packages.pytestCheckHook
          pkgs.python3Packages.pytest-cov
        ];

        meta.mainProgram = builtins.head (builtins.attrNames project.scripts);
      };
    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        name = "python";
        packages = [
          pkgs.python3
          pkgs.uv
          pkgs.ruff
        ];

        env =
          {
            UV_PYTHON = pkgs.python3.interpreter;
            UV_PYTHON_DOWNLOADS = "never";
          }
          // nixpkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            LD_LIBRARY_PATH = nixpkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.zlib
            ];
          };
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}

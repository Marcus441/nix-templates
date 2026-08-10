{
  description = "Dev environment for a minimal production-ready Rust project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (
        system: f (import nixpkgs {inherit system;})
      );

    project = "myproject";
  in {
    packages = forAllSystems (pkgs: {
      default = pkgs.rustPlatform.buildRustPackage {
        pname = project;
        version = "0.1.0";
        src = ./.;
        cargoLock.lockFile = ./Cargo.lock;

        nativeBuildInputs = [pkgs.pkg-config];
        buildInputs = [];

        meta.mainProgram = project;
      };
    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        name = "rust";
        inputsFrom = [self.packages.${pkgs.system}.default];
        packages = [
          pkgs.clippy
          pkgs.rustfmt
          pkgs.rust-analyzer
          pkgs.gdb
        ];
        env.RUST_BACKTRACE = "1";
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}

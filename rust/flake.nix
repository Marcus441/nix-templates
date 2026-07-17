{
  description = "A minimal production-ready Rust template";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      project = "myproject";
    in {
      # `cargo test` runs in the checkPhase by default
      packages.default = pkgs.rustPlatform.buildRustPackage {
        pname = project;
        version = "0.1.0";
        src = ./.;
        cargoLock.lockFile = ./Cargo.lock;

        # for crates that link system C libraries: pkg-config finds them,
        # the libraries themselves go in buildInputs
        nativeBuildInputs = with pkgs; [pkg-config];
        buildInputs = with pkgs; [];
      };

      devShells.default = pkgs.mkShell {
        name = "${project}-shell";
        inputsFrom = [self.packages.${system}.default];
        nativeBuildInputs = with pkgs; [
          clippy
          rustfmt
          rust-analyzer
          gdb
        ];
        env.RUST_BACKTRACE = "1";
      };
    });
}

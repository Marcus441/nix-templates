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

    crate = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).package;
  in {
    packages = forAllSystems (pkgs: {
      default = pkgs.rustPlatform.buildRustPackage {
        pname = crate.name;
        inherit (crate) version;
        src = ./.;
        cargoLock.lockFile = ./Cargo.lock;

        nativeBuildInputs = [pkgs.pkg-config];

        meta.mainProgram = crate.name;
      };
    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        name = "rust";
        inputsFrom = [self.packages.${pkgs.stdenv.hostPlatform.system}.default];
        packages = [
          pkgs.clippy
          pkgs.rustfmt
          pkgs.rust-analyzer
          (
            if pkgs.stdenv.hostPlatform.isDarwin
            then pkgs.lldb
            else pkgs.gdb
          )
        ];
        env.RUST_BACKTRACE = "1";
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}

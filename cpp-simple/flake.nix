{
  description = "Dev environment for learning C++ with a plain Makefile";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs, ...}: let
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (
        system: f (import nixpkgs {inherit system;})
      );

    binary = "myproject";
  in {
    packages = forAllSystems (pkgs: {
      default = pkgs.stdenv.mkDerivation {
        pname = binary;
        version = "0.1.0";
        src = ./.;

        installPhase = ''
          runHook preInstall
          install -Dm755 ${binary} -t $out/bin
          runHook postInstall
        '';

        meta.mainProgram = binary;
      };
    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        name = "cpp-simple";
        packages = [pkgs.gnumake pkgs.llvmPackages.clang-tools pkgs.cpplint];
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}

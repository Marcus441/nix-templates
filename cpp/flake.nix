{
  description = "Dev environment for C/C++";

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

    binary = "myproject";
  in {
    packages = forAllSystems (pkgs: {
      default = pkgs.llvmPackages.stdenv.mkDerivation {
        pname = binary;
        version = "0.1.0";
        src = ./.;

        nativeBuildInputs = [
          pkgs.cmake
          pkgs.ninja
          pkgs.pkg-config
        ];

        cmakeFlags = [
          "-DCMAKE_BUILD_TYPE=Release"
          "-DUSE_SANITIZERS=OFF"
        ];

        doCheck = true;
        checkPhase = "ctest --output-on-failure";

        meta.mainProgram = binary;
      };
    });

    devShells = forAllSystems (pkgs: {
      default = (pkgs.mkShell.override {stdenv = pkgs.llvmPackages.stdenv;}) {
        name = "cpp";
        inputsFrom = [self.packages.${pkgs.system}.default];
        packages = [
          pkgs.llvmPackages.clang-tools
          pkgs.llvmPackages.lldb
          pkgs.cpplint
        ];
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}

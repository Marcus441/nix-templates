{
  description = "A minimalist C++23 development template";

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
      llvm_ver = "18";
      llvm_pkgs = pkgs."llvmPackages_${llvm_ver}";
    in {
      packages.default = pkgs.stdenv.mkDerivation {
        pname = project;
        version = "0.1.0";
        src = ./.;

        nativeBuildInputs = with pkgs; [
          llvm_pkgs.clang
          cmake
          ninja
          pkg-config
        ];

        buildInputs = with pkgs; [];

        cmakeFlags = [
          "-DCMAKE_CXX_COMPILER=clang++"
          "-DCMAKE_BUILD_TYPE=Release"
          "-DUSE_SANITIZERS=OFF"
        ];

        doCheck = true;
        checkPhase = "ctest --output-on-failure";
      };

      devShells.default = pkgs.mkShell {
        name = "${project}-dev-shell";
        inputsFrom = [self.packages.${system}.default];

        nativeBuildInputs = with pkgs; [
          llvm_pkgs.clang-tools
          llvm_pkgs.lldb
          llvm_pkgs.bintools
        ];

        shellHook = ''
          export CC=clang
          export CXX=clang++
        '';
      };
    });
}

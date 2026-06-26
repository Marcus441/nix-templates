{
  description = "A minimalist modern C++23 development template";
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
      llvm_ver = "21";
      llvm_pkgs = pkgs."llvmPackages_${llvm_ver}";
    in {
      packages.default = pkgs.stdenv.mkDerivation {
        pname = project;
        version = "0.1.0";
        src = pkgs.lib.cleanSource ./.;
        nativeBuildInputs = with pkgs; [
          cmake
          ninja
          pkg-config
        ];
        buildInputs = with pkgs; [
          gtest
        ];
        cmakeFlags = [
          "-DCMAKE_BUILD_TYPE=Release"
          "-DUSE_SANITIZERS=OFF"
          "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
          "-DCMAKE_THREAD_LIBS_INIT=-lpthread"
          "-DCMAKE_USE_PTHREADS_INIT=1"
        ];
        doCheck = true;
        checkPhase = ''
          ctest --test-dir . --build-config Release --output-on-failure
        '';
      };
      devShells.default = pkgs.mkShell {
        name = "${project}-dev-shell";
        inputsFrom = [self.packages.${system}.default];
        nativeBuildInputs = with pkgs;
          [
            llvm_pkgs.clang-tools
            llvm_pkgs.lldb
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            gdb
            valgrind
          ];
        shellHook = ''
          export CC=${llvm_pkgs.clang}/bin/clang
          export CXX=${llvm_pkgs.clang}/bin/clang++
        '';
      };
    });
}

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

      # Interchangeable toolchains: the compiler comes from the stdenv, so
      # both keep the platform-default C++ stdlib (libstdc++ on Linux) --
      # only the compiler driver differs.
      toolchains = {
        clang = {
          stdenv = llvm_pkgs.stdenv;
          shellTools = [llvm_pkgs.lldb llvm_pkgs.bintools];
        };
        gcc = {
          stdenv = pkgs.gccStdenv;
          shellTools = [pkgs.gdb];
        };
      };

      mkPackage = toolchain:
        toolchain.stdenv.mkDerivation {
          pname = project;
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = with pkgs; [
            cmake
            ninja
            pkg-config
          ];

          buildInputs = with pkgs; [];

          checkInputs = with pkgs; [gtest];

          cmakeFlags = [
            "-DCMAKE_BUILD_TYPE=Release"
            "-DUSE_SANITIZERS=OFF"
            # no network in the sandbox: use gtest from checkInputs instead
            # of FetchContent (see the disconnected branch in CMakeLists.txt)
            "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
          ];

          doCheck = true;
          checkPhase = "ctest --output-on-failure";
        };

      # CC/CXX point at the toolchain's compiler via the shell's stdenv;
      # clang-tools (clangd, clang-format, clang-tidy) ride along in both.
      mkDevShell = name: toolchain:
        (pkgs.mkShell.override {inherit (toolchain) stdenv;}) {
          name = "${project}-${name}-shell";
          inputsFrom = [(mkPackage toolchain)];
          nativeBuildInputs = [llvm_pkgs.clang-tools] ++ toolchain.shellTools;
        };
    in {
      packages =
        builtins.mapAttrs (_: mkPackage) toolchains
        // {default = self.packages.${system}.clang;};

      devShells =
        builtins.mapAttrs mkDevShell toolchains
        // {default = self.devShells.${system}.clang;};
    });
}

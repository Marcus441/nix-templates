{
  description = "Dev environment for modern C++ with modules support";

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
    binary = "my-project";
    llvmVersion = "21";

    toolchains = pkgs: let
      llvm = pkgs."llvmPackages_${llvmVersion}";
    in {
      clang = {
        inherit (llvm) stdenv;
        buildTools = [llvm.clang-tools];
        shellTools = [llvm.lldb llvm.bintools];
      };
      gcc = {
        stdenv = pkgs.gccStdenv;
        buildTools = [];
        shellTools = [pkgs.gdb];
      };
    };

    mkPackage = pkgs: toolchain:
      toolchain.stdenv.mkDerivation {
        pname = project;
        version = "0.1.0";
        src = ./.;

        nativeBuildInputs =
          [
            pkgs.cmake
            pkgs.ninja
            pkgs.pkg-config
          ]
          ++ toolchain.buildTools;

        buildInputs = [];

        checkInputs = [pkgs.gtest];

        cmakeFlags = [
          "-DCMAKE_BUILD_TYPE=Release"
          "-DUSE_SANITIZERS=OFF"
          "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
        ];

        doCheck = true;
        checkPhase = "ctest --output-on-failure";

        meta.mainProgram = binary;
      };

    mkDevShell = pkgs: name: toolchain:
      (pkgs.mkShell.override {inherit (toolchain) stdenv;}) {
        name = "cpp-modern-${name}";
        inputsFrom = [(mkPackage pkgs toolchain)];
        packages = [pkgs."llvmPackages_${llvmVersion}".clang-tools] ++ toolchain.shellTools;
      };
  in {
    packages = forAllSystems (
      pkgs:
        builtins.mapAttrs (_: mkPackage pkgs) (toolchains pkgs)
        // {default = self.packages.${pkgs.system}.clang;}
    );

    devShells = forAllSystems (
      pkgs:
        builtins.mapAttrs (mkDevShell pkgs) (toolchains pkgs)
        // {default = self.devShells.${pkgs.system}.clang;}
    );

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}

{
  description = "Dev environment for production C/C++";

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

    toolchains = pkgs: let
      llvm = pkgs.llvmPackages;
    in {
      clang = {
        inherit (llvm) stdenv;
        shellTools = [llvm.lldb llvm.bintools];
      };
      gcc = {
        stdenv = pkgs.gccStdenv;
        shellTools = [pkgs.gdb];
      };
    };

    mkPackage = pkgs: toolchain:
      toolchain.stdenv.mkDerivation {
        pname = binary;
        version = "0.1.0";
        src = ./.;

        nativeBuildInputs = [
          pkgs.cmake
          pkgs.ninja
          pkgs.pkg-config
        ];

        checkInputs = [pkgs.gtest];

        cmakeFlags = [
          "-DCMAKE_BUILD_TYPE=Release"
        ];

        doCheck = true;
        checkPhase = "ctest --output-on-failure";

        meta.mainProgram = binary;
      };

    mkDevShell = pkgs: name: toolchain:
      (pkgs.mkShell.override {inherit (toolchain) stdenv;}) {
        name = "cpp-prod-${name}";
        inputsFrom = [(mkPackage pkgs toolchain)];
        packages =
          [
            pkgs.llvmPackages.clang-tools
            pkgs.cpplint
            pkgs.gcovr
          ]
          ++ toolchain.shellTools;
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

{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      devShell = pkgs.mkShell {
        name = "C++ DevShell";

        buildInputs = with pkgs; [
          cmake
          gnumake
          bear
          clang # Clang
          clang-tools # Extra tools: clang-format, clang-tidy, etc.
          lldb # LLVM debugger
          gdb # GNU debugger for comparison
        ];

        shellHook = ''
          echo "🛠️  C++ dev shell with Clang"
          echo "🔧  Compiler: $("${pkgs.clang}/bin/clang" --version | head -n 1)"
        '';
      };
    });
}

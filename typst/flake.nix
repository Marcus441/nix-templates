{
  description = "Typst document environment with font plumbing";
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
      # import any fonts in here
      fonts = with pkgs; [
        font-awesome
      ];
      fontConf = pkgs.makeFontsConf {
        fontDirectories = [
          (pkgs.linkFarm "fonts" (map (f: {
              inherit (f) name;
              path = f;
            })
            fonts))
        ];
      };
    in {
      devShells.default = pkgs.mkShell {
        name = "Typst shell";

        buildInputs = [pkgs.typst] ++ fonts;

        FONTCONFIG_FILE = fontConf;

        shellHook = ''
          echo "╔═══════════════════════════════╗"
          echo "║  🖋 Typst Development Shell 🖋  ║"
          echo "╚═══════════════════════════════╝"
          echo "Run 'typst --help' to get started!"
          echo
          echo "Checking fonts available to Typst..."
          typst fonts | grep -E "Source|Roboto|Awesome" || echo "⚠️  Fonts not detected!"
        '';
      };
    });
}

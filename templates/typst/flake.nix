{
  description = "Dev environment for Typst documents";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs, ...}: let
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (
        system: f (import nixpkgs {inherit system;})
      );
  in {
    devShells = forAllSystems (pkgs: let
      fonts = [pkgs.font-awesome];
      fontsConf = pkgs.makeFontsConf {
        fontDirectories = [
          (pkgs.linkFarm "fonts" (map (f: {
              inherit (f) name;
              path = f;
            })
            fonts))
        ];
      };
    in {
      default = pkgs.mkShellNoCC {
        name = "typst";
        packages = [pkgs.typst] ++ fonts;
        env.FONTCONFIG_FILE = "${fontsConf}";
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}

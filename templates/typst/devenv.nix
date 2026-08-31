{pkgs, ...}: let
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
  packages = [pkgs.typst] ++ fonts;

  env.FONTCONFIG_FILE = "${fontsConf}";

  enterTest = ''
    typst compile docs/example.typ
    test -s docs/example.pdf
  '';
}

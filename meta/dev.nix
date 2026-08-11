{inputs, ...}: {
  imports = [inputs.treefmt-nix.flakeModule];

  perSystem = {
    pkgs,
    config,
    ...
  }: {
    # Gives both `nix fmt` and checks.treefmt.
    treefmt = {
      projectRootFile = "flake.nix";
      programs.alejandra.enable = true;
      programs.shfmt.enable = true;
      settings.global.excludes = [
        "*.lock"
      ];
    };

    devShells.default = pkgs.mkShell {
      name = "nix-templates";
      packages = [
        pkgs.jq
        pkgs.gh
        pkgs.shellcheck
        config.treefmt.build.wrapper
      ];
      shellHook = ''
        echo "nix flake check              static checks"
        echo "./scripts/test-template.sh   instantiate and test every template"
      '';
    };
  };
}

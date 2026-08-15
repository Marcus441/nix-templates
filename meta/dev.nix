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
      # The upstream default is *.sh, *.bash, *.envrc, *.envrc.* — restated
      # because a definition replaces it rather than extending it. Git requires
      # its hooks be named `commit-msg` and `pre-push`, with no extension, so
      # without .githooks/* they would be shell the formatter cannot see.
      programs.shfmt.includes = [
        "*.sh"
        "*.bash"
        "*.envrc"
        "*.envrc.*"
        ".githooks/*"
      ];
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

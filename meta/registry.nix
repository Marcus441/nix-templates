{
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption types;

  template = types.submodule ({name, ...}: {
    options = {
      description = mkOption {
        type = types.str;
        description = "Shown by `nix flake show` and `nix flake init -t`.";
      };

      tier = mkOption {
        type = types.enum ["eval" "shell" "build"];
        default = "shell";
        description = "How far the harness goes. CLAUDE.md 3.";
      };

      smoke = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Commands run inside `nix develop` at tier >= shell.";
      };

      systems = mkOption {
        type = types.listOf types.str;
        default = config.systems;
        description = "Systems the harness may test this template on.";
      };

      locked = mkOption {
        type = types.bool;
        default = false;
        description = "Ships a committed flake.lock. Must agree with .gitignore.";
      };

      unfree = mkOption {
        type = types.bool;
        default = false;
        description = "Harness exports NIXPKGS_ALLOW_UNFREE and passes --impure.";
      };

      reason = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Why this template cannot be proven further. Required below tier build.";
      };

      # Known-broken, tracked, and deliberately not being fixed right now. The
      # harness expects the failure (XFAIL) so CI is honest rather than red —
      # and complains if it ever starts passing. Requires a reason.
      broken = mkOption {
        type = types.bool;
        default = false;
        description = "Failure at this tier is expected and tracked. CLAUDE.md 7.";
      };

      # Printed by `nix flake init -t` once the copy is done. Left null so the
      # standard text below applies; set it only when a template needs to say
      # something the standard text cannot.
      welcomeText = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Overrides the standard post-init message.";
      };

      path = mkOption {
        type = types.path;
        default = ../. + "/${name}";
        defaultText = "../<name>";
        description = "Derived from the attribute name; the directory name is the template name.";
      };
    };
  });

  # `nix flake init` is the one moment a consumer is guaranteed to be looking,
  # and the first thing they hit is that a flake ignores untracked files. Say
  # it here rather than leaving it to a README they have not opened yet.
  standardWelcome = name: t: ''
    # ${name}

    ${t.description}

    A flake only sees files that git tracks, so initialise the repository
    before entering the shell:

    ```
    git init && git add -A
    nix develop            # or: direnv allow
    ```

    `README.md` covers building, testing and what to change first.
  '';

  mapped =
    lib.mapAttrs (name: t: {
      inherit (t) path description;
      welcomeText =
        if t.welcomeText != null
        then t.welcomeText
        else standardWelcome name t;
    })
    config.templates;
in {
  options = {
    templates = mkOption {
      type = types.attrsOf template;
      default = {};
      description = "The registry. The single source of truth — CLAUDE.md 1.2.";
    };

    defaultTemplate = mkOption {
      type = types.str;
      default = "shell";
      description = "Copied by `nix flake init` with no -t.";
    };
  };

  config.flake.templates = mapped // {default = mapped.${config.defaultTemplate};};
}

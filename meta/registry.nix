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
        description = "Commands run in the template's shell at tier >= shell, via `devenv shell --`.";
      };

      systems = mkOption {
        type = types.listOf types.str;
        default = config.systems;
        description = "Systems the harness may test this template on.";
      };

      locked = mkOption {
        type = types.bool;
        default = false;
        description = "Ships a committed devenv.lock. Must agree with .gitignore.";
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
        default = ../templates + "/${name}";
        defaultText = "../templates/<name>";
        description = "Derived from the attribute name; the directory name is the template name.";
      };
    };
  });

  # `nix flake init` is the one moment a consumer is guaranteed to be looking,
  # and the first thing they hit is that there is no flake here: the template
  # needs devenv installed. Say it here rather than leaving it to a README they
  # have not opened yet.
  standardWelcome = name: t: ''
    # ${name}

    ${t.description}

    This is a devenv environment rather than a flake: there is no
    `flake.nix`, and `nix develop` does not apply here. Install devenv —
    https://devenv.sh — then:

    ```
    git init && git add -A
    devenv shell           # or: direnv allow
    ```

    `README.md` covers the services, the test command and what to change
    first.
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
      default = "devenv";
      description = "Copied by `nix flake init` with no -t.";
    };
  };

  config.flake.templates = mapped // {default = mapped.${config.defaultTemplate};};
}

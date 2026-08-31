# Static checks only. A derivation cannot instantiate a template — no network,
# no recursive-nix — so everything that proves a template actually *works* lives
# in scripts/test-template.sh instead. .claude/rules/harness.md.
{
  lib,
  config,
  ...
}: {
  perSystem = {pkgs, ...}: let
    templates = config.templates;
    names = lib.attrNames templates;
    root = ../templates;

    # `nix build` and `direnv allow` leave droppings in every generated project,
    # whatever the language, so this block is the one part of a .gitignore that
    # has no business differing between templates. Escaped rather than an
    # indented string so the exact four lines are visible here.
    nixGitignoreBlock = "# Nix\nresult\nresult-*\n.direnv/";

    # Interpolating a template path that does not exist throws at *eval*, which
    # would take `nix flake check` down for every template rather than just the
    # one at fault — a half-added template must fail its check, not the whole
    # run. Hence this guard on every source read. `nix flake show`,
    # `nix flake init -t` and `nix build .#registry-json` are unaffected — none
    # of them forces a check derivation.
    exists = n: f: builtins.pathExists (root + "/${n}/${f}");

    # The nixpkgs pin as devenv.yaml spells it. Whole lines, so the formatting
    # is pinned along with the value. devenv's own default is
    # github:cachix/devenv-nixpkgs/rolling, so this is load-bearing rather than
    # decorative — Inv. 5 is the reason, and docs/decisions/devenv-templates.md
    # records what to do if a devenv module ever needs that fork.
    devenvNixpkgsLines = [
      "  nixpkgs:"
      "    url: github:nixos/nixpkgs/nixos-unstable"
    ];

    # Inv. 6. The four dotfiles, plus the artifact.
    requiredFiles = [".editorconfig" ".envrc" ".gitignore" "README.md" "devenv.nix" "devenv.yaml"];

    # A template that also shipped a flake.nix would be two definitions of one
    # environment with nothing checking that they agree — the hybrid
    # docs/decisions/devenv.md rejected on its own merits. This is what keeps
    # that rejection alive: the first "flake.nix for compatibility" fails here.
    forbiddenFiles = ["flake.nix" "flake.lock"];

    # Everything under templates/ is a template. Nothing else lives there, which
    # is why this needs no denylist of repository machinery.
    dirs =
      lib.attrNames
      (lib.filterAttrs
        (n: type: type == "directory" && !(lib.hasPrefix "." n))
        (builtins.readDir root));

    # A check whose verdict is known at eval time. Empty list means pass.
    decided = name: problems:
      pkgs.runCommand "check-${name}" {
        problems = lib.concatStringsSep "\n" problems;
        passAsFile = ["problems"];
      } ''
        if [ -s "$problemsPath" ]; then
          echo "${name}:" >&2
          sed 's/^/  /' "$problemsPath" >&2
          exit 1
        fi
        touch "$out"
      '';
  in {
    checks = {
      # Inv. 3. `nix flake check` already rejects a dangling `path`, so this
      # only has to catch the other direction: a directory nobody registered.
      registry-bijection = decided "registry-bijection" (
        map (n: "directory '${n}/' is not registered in meta/templates.nix")
        (lib.subtractLists names dirs)
        ++ map (n: "registry entry '${n}' has no directory")
        (lib.subtractLists dirs names)
      );

      # Templates are copied verbatim and cannot share code (Inv. 1), so
      # copy-paste is how they get written — and a description carried over
      # from the template it was copied from is the cheapest signal that other
      # lines were carried over too. It is how `node-rest-api` was found to
      # ship `node`'s flake, and `python-jetson` to ship `cpp-jetson`'s.
      #
      # Read from the registry: the registry entry is the line a human copies
      # first, and a devenv template has no artifact description to compare.
      description-unique = decided "description-unique" (
        let
          descOf = n: templates.${n}.description;
          countOf = d: lib.count (n: descOf n == d) names;
          dupes = lib.unique (lib.filter (d: countOf d > 1) (map descOf names));
        in
          map (
            d: "shared by ${lib.concatStringsSep ", " (lib.filter (n: descOf n == d) names)}: \"${d}\""
          )
          dupes
      );

      # CLAUDE.md 3 — a narrowed tier without a reason is how the repo stops
      # describing itself.
      reason-required = decided "reason-required" (
        lib.concatMap (
          n: let
            t = templates.${n};
            narrowed = t.systems != config.systems;
          in
            lib.optional
            (t.reason == null && (t.tier != "build" || narrowed))
            (
              "'${n}': tier=\"${t.tier}\""
              + lib.optionalString narrowed " with narrowed systems"
              + " requires a reason"
            )
        )
        names
      );

      # CLAUDE.md 5 — the flag and the tracked file must agree, or .gitignore
      # is silently dropping a lock a consumer is meant to get.
      lock-policy = decided "lock-policy" (
        lib.concatMap (
          n: let
            t = templates.${n};
            shipped = exists n "devenv.lock";
          in
            if t.locked && !shipped
            then ["'${n}' is locked=true but ships no devenv.lock — is it still gitignored?"]
            else if !t.locked && shipped
            then ["'${n}' is locked=false but ships a devenv.lock"]
            else []
        )
        names
      );

      # Inv. 4, Inv. 5 and Inv. 1 at the artifact level. devenv.yaml's own
      # default nixpkgs is github:cachix/devenv-nixpkgs/rolling, which means
      # the pin has to be written out rather than inherited.
      #
      # Both files are searched for `../`, not just the yaml: a devenv template
      # has one more way out of its own directory than a flake had, and it is
      # `imports = [ ../shared.nix ];` in devenv.nix. A `path:` input is not
      # banned — `path:./sub` is inside the directory and legitimate.
      devenv-inputs = pkgs.runCommand "check-devenv-inputs" {} ''
        fail=0
        ${lib.concatMapStringsSep "\n" (n:
          lib.optionalString (exists n "devenv.yaml") (
            lib.concatMapStringsSep "\n" (l: ''
              if ! grep -qxF ${lib.escapeShellArg l} ${root + "/${n}/devenv.yaml"}; then
                echo "  ${n}: devenv.yaml does not carry the line: ${l}" >&2
                fail=1
              fi
            '')
            devenvNixpkgsLines
          )
          + lib.concatMapStringsSep "\n" (f:
            lib.optionalString (exists n f) ''
              if grep -qE '\.\./' ${root + "/${n}/${f}"}; then
                echo "  ${n}: ${f} references ../ — the copy would dangle (Inv. 1)" >&2
                fail=1
              fi
            '')
          ["devenv.yaml" "devenv.nix"]
          + lib.optionalString (exists n "devenv.yaml") ''
            if grep -qE '^[[:space:]]*-[[:space:]]*/' ${root + "/${n}/devenv.yaml"}; then
              echo "  ${n}: devenv.yaml has an absolute-path list entry (Inv. 1)" >&2
              fail=1
            fi
            urls=$(grep -cE '^[[:space:]]*url:' ${root + "/${n}/devenv.yaml"} || true)
            if [ "$urls" != 1 ]; then
              echo "  ${n}: devenv.yaml declares $urls inputs; nixpkgs must be the only one (Inv. 4)" >&2
              fail=1
            fi
          '')
        names}
        if [ $fail -ne 0 ]; then
          echo "devenv-inputs: see .claude/rules/template-devenv-conventions.md" >&2
          exit 1
        fi
        touch "$out"
      '';

      # Inv. 6. Every template ships the same four dotfiles plus devenv.nix and
      # devenv.yaml, so a consumer never has to wonder whether this one happens
      # to have a README. The forbidden list is the other half — one
      # environment, one definition of it.
      template-hygiene = pkgs.runCommand "check-template-hygiene" {} ''
        # Single-quoted so nothing in it is expanded; compared against head -4.
        expected_nix_block='${nixGitignoreBlock}'
        missing=0
        ${lib.concatMapStringsSep "\n" (n: ''
            for f in ${lib.escapeShellArgs requiredFiles}; do
              if [ ! -e ${root + "/${n}"}/"$f" ]; then
                echo "  ${n}: missing $f" >&2
                missing=$((missing + 1))
              fi
            done
            for f in ${lib.escapeShellArgs forbiddenFiles}; do
              if [ -e ${root + "/${n}"}/"$f" ]; then
                echo "  ${n}: ships $f — the environment is defined once, in devenv.nix" >&2
                missing=$((missing + 1))
              fi
            done
            if [ "$(head -n 4 ${root + "/${n}"}/.gitignore)" != "$expected_nix_block" ]; then
              echo "  ${n}: .gitignore does not open with the Nix block" >&2
              missing=$((missing + 1))
            fi
            if [ "$(head -n 1 ${root + "/${n}"}/README.md)" != '# ${n}' ]; then
              echo "  ${n}: README.md does not open with '# ${n}'" >&2
              missing=$((missing + 1))
            fi
            if ! grep -q '^## Building$' ${root + "/${n}"}/README.md; then
              echo "  ${n}: README.md has no '## Building' section" >&2
              missing=$((missing + 1))
            fi
          '')
          names}
        if [ $missing -ne 0 ]; then
          echo "template-hygiene: $missing problem(s) (Inv. 6)" >&2
          printf '%s\n' "every template .gitignore must open with:" "$expected_nix_block" >&2
          exit 1
        fi
        touch "$out"
      '';
    };
  };
}

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
    root = ../.;

    canonicalUrl = ''nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"'';

    # `nix build` and `direnv allow` leave droppings in every generated project,
    # whatever the language, so this block is the one part of a .gitignore that
    # has no business differing between templates. Escaped rather than an
    # indented string so the exact four lines are visible here.
    nixGitignoreBlock = "# Nix\nresult\nresult-*\n.direnv/";

    # The `systems` line a template's flake.nix must carry, rendered from the
    # registry so the two cannot drift. Indentation included: it is a whole-line
    # match, which is the cheapest way to also pin the formatting.
    systemsLine = n:
      "    systems = ["
      + lib.concatMapStringsSep " " (s: ''"${s}"'') templates.${n}.systems
      + "];";

    # Directories that are repository machinery rather than templates.
    notTemplates = ["meta" "scripts" "docs"];

    dirs =
      lib.attrNames
      (lib.filterAttrs
        (n: type:
          type
          == "directory"
          && !(lib.hasPrefix "." n)
          && !(builtins.elem n notTemplates))
        (builtins.readDir root));

    # The `description` of a template's own flake.nix, as text. Null when the
    # template has none. Extracted rather than imported: importing every
    # template's flake.nix would make a syntax error in any one of them fail
    # the whole root evaluation, including `nix flake show`.
    descriptionOf = n: let
      m =
        builtins.match ''.*[\n]?[[:space:]]*description = "([^"]*)";.*''
        (builtins.readFile (root + "/${n}/flake.nix"));
    in
      if m == null
      then null
      else builtins.head m;

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
      description-unique = decided "description-unique" (
        let
          described = lib.filter (n: descriptionOf n != null) names;
          countOf = d: lib.count (n: descriptionOf n == d) described;
          dupes = lib.unique (lib.filter (d: countOf d > 1) (map descriptionOf described));
        in
          map (
            d: "shared by ${lib.concatStringsSep ", " (lib.filter (n: descriptionOf n == d) described)}: \"${d}\""
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
            shipped = builtins.pathExists (root + "/${n}/flake.lock");
          in
            if t.locked && !shipped
            then ["'${n}' is locked=true but ships no flake.lock — is it still gitignored?"]
            else if !t.locked && shipped
            then ["'${n}' is locked=false but ships a flake.lock"]
            else []
        )
        names
      );

      # Inv. 4 and Inv. 5. One URL spelling, one system-iteration idiom, and a
      # `systems` list that says the same thing the registry does — a template
      # that claims a system the registry excludes is untested by construction.
      flake-inputs = pkgs.runCommand "check-flake-inputs" {} ''
        # Single-quoted: canonicalUrl contains double quotes of its own.
        expected='${canonicalUrl}'
        fail=0
        ${lib.concatMapStringsSep "\n" (n: ''
            found=$(grep -oE 'nixpkgs\.url = "[^"]*"' ${root + "/${n}/flake.nix"} | head -1 || true)
            if [ "$found" != "$expected" ]; then
              echo "  ${n}: nixpkgs pinned as $found" >&2
              fail=1
            fi
            if grep -q 'flake-utils' ${root + "/${n}/flake.nix"}; then
              echo "  ${n}: uses flake-utils; iterate systems with nixpkgs.lib.genAttrs" >&2
              fail=1
            fi
            if ! grep -qxF '${systemsLine n}' ${root + "/${n}/flake.nix"}; then
              echo "  ${n}: flake does not declare ${systemsLine n}" >&2
              fail=1
            fi
          '')
          names}
        if [ $fail -ne 0 ]; then
          echo "flake-inputs: see .claude/rules/template-flake-conventions.md" >&2
          exit 1
        fi
        touch "$out"
      '';

      # `nix flake init -t` prints the registry's description and the consumer
      # then reads the flake's. Two sentences for one template is one too many.
      description-agrees = decided "description-agrees" (
        lib.concatMap (
          n: let
            inFlake = descriptionOf n;
            inRegistry = templates.${n}.description;
          in
            lib.optional (inFlake != null && inFlake != inRegistry)
            "'${n}': flake says \"${inFlake}\", registry says \"${inRegistry}\""
        )
        names
      );

      # Without the ellipsis, adding any input is a breaking change for every
      # project generated from the template.
      outputs-ellipsis = pkgs.runCommand "check-outputs-ellipsis" {} ''
        fail=0
        ${lib.concatMapStringsSep "\n" (n: ''
            if ! sed -n '/outputs = {/,/}:/p' ${root + "/${n}/flake.nix"} | grep -q '\.\.\.'; then
              echo "  ${n}: outputs argument set has no '...' ellipsis" >&2
              fail=1
            fi
          '')
          names}
        if [ $fail -ne 0 ]; then
          echo "outputs-ellipsis: see .claude/rules/template-flake-conventions.md" >&2
          exit 1
        fi
        touch "$out"
      '';

      # Inv. 6. Enforcing: every template ships the same five things, so a
      # consumer never has to wonder whether this one happens to have a README.
      template-hygiene = pkgs.runCommand "check-template-hygiene" {} ''
        # Single-quoted so nothing in it is expanded; compared against head -4.
        expected_nix_block='${nixGitignoreBlock}'
        missing=0
        ${lib.concatMapStringsSep "\n" (n: ''
            for f in .editorconfig .envrc .gitignore README.md; do
              if [ ! -e ${root + "/${n}"}/"$f" ]; then
                echo "  ${n}: missing $f" >&2
                missing=$((missing + 1))
              fi
            done
            if ! grep -q '^  description = ' ${root + "/${n}/flake.nix"}; then
              echo "  ${n}: flake.nix has no description" >&2
              missing=$((missing + 1))
            fi
            if [ "$(head -n 4 ${root + "/${n}"}/.gitignore)" != "$expected_nix_block" ]; then
              echo "  ${n}: .gitignore does not open with the Nix block" >&2
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

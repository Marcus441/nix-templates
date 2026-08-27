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

    # Inv. 4, all five. Matched as an attribute-path head (`devenv.url = …`,
    # `flake-parts.lib.mkFlake`, `{self, flake-parts, ...}`) or anywhere in a
    # flake ref, which also catches an aliased input. A preceding `.` is
    # excluded so a nixpkgs package of the same name in a dev shell's
    # `packages` cannot trip it.
    bannedFrameworks = ["flake-utils" "flake-parts" "import-tree" "devenv" "snowfall"];

    # Everything under templates/ is a template. Nothing else lives there, which
    # is why this needs no denylist of repository machinery.
    dirs =
      lib.attrNames
      (lib.filterAttrs
        (n: type: type == "directory" && !(lib.hasPrefix "." n))
        (builtins.readDir root));

    # The `description` of a template's own flake.nix, as text. Null when the
    # template has none, and null when it has no flake.nix at all. Extracted
    # rather than imported: importing every template's flake.nix would make a
    # syntax error in any one of them fail the whole root evaluation,
    # including `nix flake show`.
    #
    # A missing file is that same failure class and is guarded for the same
    # reason — builtins.readFile on a path that does not exist throws at eval,
    # so one unreadable template would take `nix flake show` down for all of
    # them. That is a consumer-facing break: `nix flake init -t` and
    # `nix build .#registry-json` keep working, so nothing a maintainer runs
    # would notice.
    descriptionOf = n: let
      f = root + "/${n}/flake.nix";
      m =
        if !(builtins.pathExists f)
        then null
        else
          builtins.match ''.*[\n]?[[:space:]]*description = "([^"]*)";.*''
          (builtins.readFile f);
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
      #
      # Read from the registry rather than from the artifact. The registry
      # entry is the line a human copies first, `description-agrees` ties the
      # two together for a flake, and this way the check is total: a flake
      # whose description the regex cannot extract used to fall out of *both*
      # checks silently, and a template with no flake.nix has no artifact
      # description to compare at all.
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

      # Inv. 4 and Inv. 5. One URL spelling, no framework, and a `systems` list
      # that says the same thing the registry does — a template that claims a
      # system the registry excludes is untested by construction.
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
            ${lib.concatMapStringsSep "\n" (f: ''
                if grep -qE '(^|[^[:alnum:]_.-])${f}([.,}[:space:]]|$)|url = .*${f}' ${root + "/${n}/flake.nix"}; then
                  echo "  ${n}: uses ${f}; a template's only input is nixpkgs" >&2
                  fail=1
                fi
              '')
              bannedFrameworks}
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

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

    # CLAUDE.md 1.4. A "flake" template ships flake.nix on one nixpkgs input; a
    # "devenv" template ships devenv.nix and devenv.yaml and no flake.nix at
    # all. Every check below that reads a template's *source* has to know which,
    # because interpolating a path that does not exist throws at eval — it would
    # take `nix flake show` down for every template, and only a consumer would
    # notice, since `nix flake init -t` and `nix build .#registry-json` keep
    # working.
    kindOf = n: templates.${n}.kind;
    flakeNames = lib.filter (n: kindOf n == "flake") names;
    devenvNames = lib.filter (n: kindOf n == "devenv") names;
    exists = n: f: builtins.pathExists (root + "/${n}/${f}");

    # The nixpkgs pin as devenv.yaml spells it. Whole lines, like systemsLine,
    # so the formatting is pinned along with the value. devenv's own default is
    # github:cachix/devenv-nixpkgs/rolling, so this is load-bearing rather than
    # decorative — Inv. 5 is the reason, and docs/decisions/devenv-templates.md
    # records what to do if a devenv module ever needs that fork.
    devenvNixpkgsLines = [
      "  nixpkgs:"
      "    url: github:nixos/nixpkgs/nixos-unstable"
    ];

    # Inv. 6, per kind. The four dotfiles are common to both; the artifact is
    # not.
    requiredFiles = n:
      [".editorconfig" ".envrc" ".gitignore" "README.md"]
      ++ (
        if kindOf n == "devenv"
        then ["devenv.nix" "devenv.yaml"]
        else ["flake.nix"]
      );

    # The other shape's artifacts, which must be absent. This is what keeps
    # docs/decisions/devenv.md's rejection of a hybrid alive after the
    # reversal: one environment, one definition of it. Without this, the first
    # person to add a flake.nix "for compatibility" reinstates the two
    # definitions with nothing checking that they agree.
    forbiddenFiles = n:
      if kindOf n == "devenv"
      then ["flake.nix" "flake.lock"]
      else ["devenv.nix" "devenv.yaml" "devenv.lock"];

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
            lockFile =
              if t.kind == "devenv"
              then "devenv.lock"
              else "flake.lock";
            shipped = exists n lockFile;
          in
            if t.locked && !shipped
            then ["'${n}' is locked=true but ships no ${lockFile} — is it still gitignored?"]
            else if !t.locked && shipped
            then ["'${n}' is locked=false but ships a ${lockFile}"]
            else []
        )
        names
      );

      # Inv. 4 and Inv. 5, for kind = "flake". One URL spelling, no framework,
      # and a `systems` list that says the same thing the registry does — a
      # template that claims a system the registry excludes is untested by
      # construction. The devenv shape has no flake.nix and no `systems` of its
      # own; `devenv-inputs` covers what it can, and CLAUDE.md 1.4 records the
      # asymmetry that remains.
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
          flakeNames}
        if [ $fail -ne 0 ]; then
          echo "flake-inputs: see .claude/rules/template-flake-conventions.md" >&2
          exit 1
        fi
        touch "$out"
      '';

      # `nix flake init -t` prints the registry's description and the consumer
      # then reads the flake's. Two sentences for one template is one too many.
      # kind = "devenv" has nowhere to put a second one, which is why
      # `description-unique` reads the registry rather than the artifact.
      description-agrees = decided "description-agrees" (
        lib.concatMap (
          n: let
            inFlake = descriptionOf n;
            inRegistry = templates.${n}.description;
          in
            lib.optional (inFlake != null && inFlake != inRegistry)
            "'${n}': flake says \"${inFlake}\", registry says \"${inRegistry}\""
        )
        flakeNames
      );

      # Inv. 5 and Inv. 1 for the shape that has no flake.nix, so `flake-inputs`
      # cannot speak for it. devenv.yaml's own default nixpkgs is
      # github:cachix/devenv-nixpkgs/rolling, which means the pin has to be
      # written out rather than inherited.
      #
      # Both files are searched for `../`, not just the yaml: a devenv template
      # has one more way out of its own directory than a flake does, and it is
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
          '')
        devenvNames}
        if [ $fail -ne 0 ]; then
          echo "devenv-inputs: see .claude/rules/template-devenv-conventions.md" >&2
          exit 1
        fi
        touch "$out"
      '';

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
          flakeNames}
        if [ $fail -ne 0 ]; then
          echo "outputs-ellipsis: see .claude/rules/template-flake-conventions.md" >&2
          exit 1
        fi
        touch "$out"
      '';

      # Inv. 6. Every template ships the same four dotfiles plus the artifact
      # its kind calls for, so a consumer never has to wonder whether this one
      # happens to have a README. The forbidden list is the other half: a
      # devenv template that also shipped a flake.nix would be two definitions
      # of one environment with nothing checking that they agree, which is the
      # hybrid docs/decisions/devenv.md rejected on its own merits.
      template-hygiene = pkgs.runCommand "check-template-hygiene" {} ''
        # Single-quoted so nothing in it is expanded; compared against head -4.
        expected_nix_block='${nixGitignoreBlock}'
        missing=0
        ${lib.concatMapStringsSep "\n" (n: ''
            for f in ${lib.escapeShellArgs (requiredFiles n)}; do
              if [ ! -e ${root + "/${n}"}/"$f" ]; then
                echo "  ${n}: missing $f" >&2
                missing=$((missing + 1))
              fi
            done
            for f in ${lib.escapeShellArgs (forbiddenFiles n)}; do
              if [ -e ${root + "/${n}"}/"$f" ]; then
                echo "  ${n}: kind=\"${kindOf n}\" but ships $f" >&2
                missing=$((missing + 1))
              fi
            done
            ${lib.optionalString (kindOf n == "flake" && exists n "flake.nix") ''
              if ! grep -q '^  description = ' ${root + "/${n}/flake.nix"}; then
                echo "  ${n}: flake.nix has no description" >&2
                missing=$((missing + 1))
              fi
            ''}
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

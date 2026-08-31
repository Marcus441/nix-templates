# devenv stays out of the templates and the registry

**Why:** the case for devenv here is usually made as a boilerplate argument, and
that case does not hold. The canonical preamble — description, one input,
`systems`, `forAllSystems` — is about thirteen lines, and it is *constant*: it
does not grow with the complexity of the environment it opens.
`templates/ts-node/flake.nix` is forty-four lines complete, package and dev
shell included. What devenv actually buys is `services.<db>.enable` and the
process-compose supervision behind it. That is a services argument, not a
brevity argument, and no template in this repo needs services today.

**Breaks:** the consumer pays for it. `nix flake init -t` followed by
`nix develop` works on a stock Nix install right now; a devenv template requires
devenv installed, and in practice its cachix as well, before the generated
project does anything. `docs/decisions/flake-parts-at-root.md` books one
knowingly accepted consumer fetch already — this is a much larger version of the
same cost, and unlike that one it is paid by every person who inits, not by this
repo's maintainer. What is given up in exchange is supervised services, which
nothing here currently wants.

**Rejected: a hybrid `.envrc`** — `use devenv` with a fallback to `use flake`.
This is the worst of the options, not a compromise. The template would ship two
definitions of one environment with nothing checking that they agree, and which
one a developer gets would depend on their PATH. The flake stays mandatory
either way: `template-hygiene` requires a `flake.nix` with a `description`, and
the `build` tier runs `nix build .#default`. So the harness's
`nix develop --command` would be proving the fallback path while developers used
the devenv one — a green tier testing the road not taken, which is the §3
failure mode exactly.

**Superseded on this point — see `docs/decisions/devenv-templates.md`, then
`docs/decisions/devenv-only.md`.** The paragraph below deferred the decision;
the trigger it was waiting for arrived, and devenv became a `kind` in the
registry — the cost estimate turned out to be accurate and was paid
deliberately, scoped to the templates that chose it. `devenv-only.md` then
removed the scope along with the flake kind: every template is native devenv,
so the **Breaks** paragraph above is no longer one option's price but the
repository's accepted posture. The hybrid rejection above still stands on its
own merits — `template-hygiene` now forbids any template shipping a
`flake.nix` — and the enforcement note at the end describes a check,
`flake-inputs`, that is gone with the kind it guarded.

**Rejected: first-class devenv support in the registry.** It is new machinery,
not a style change: a `kind` field in `meta/registry.nix`; `flake-inputs`,
`lock-policy` and `template-hygiene` each branching on it; a second harness path
in `scripts/test-template.sh`, which has to stay bash 3.2 compatible for the
macOS runners (§7.10); and a second lock format, since `devenv.lock` sits beside
`flake.lock` and both §5 and the `lock-policy` check know only the latter. That
is a lot of surface for a capability no entry has asked for.

**Also:** if a template ever genuinely needs supervised services, there are two
honest answers. A plain devShell plus `pkgs.process-compose` and a shipped
`process-compose.yaml` keeps one input and every invariant intact, and is the
first thing to try. Failing that, a separate `devenv-templates` repo, where the
consumer opts into the toolchain by choosing the repo. Decide between them when
such a template actually exists, not before.

Enforcement is shared with `docs/decisions/no-flake-utils.md`: Inv. 4 names five
frameworks, and `checks.flake-inputs` greps every template's `flake.nix` for all
of them. devenv is banned by the same line of the same check as flake-utils, for
the same reason — a generated project should not inherit a framework it did not
ask for.

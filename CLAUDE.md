# CLAUDE.md — flake templates

This repository publishes **project templates** consumed by
`nix flake init -t github:Marcus441/nix-templates#<name>`. Its product is not a
configuration — it is eleven standalone flakes that other people copy. That one
fact drives every rule below. If a change would violate an invariant, stop and
say so.

§7 lists where the repo does **not yet** satisfy its own invariants. Read it
before treating existing code as an example to copy.

**This is not `~/.dotfiles/flake/`.** That repo is dendritic; this one is
deliberately not. The reasoning is in §2 — do not "fix" the inconsistency.

## 1. Invariants

1. **A template is copied verbatim.** `nix flake init` copies the template
   directory and nothing else. A template can therefore **never** reference a
   path outside its own directory, import repo code, or depend on the root
   flake. **No shared Nix library between templates is possible.** Duplication
   across templates is constrained by lint, never removed by abstraction.
2. **`meta/templates.nix` is the single source of truth.** `flake.templates` is
   *derived* from it. Never write `flake.templates` by hand — and note nix
   enforces this, not taste: `templates.<name>` accepts only `path`,
   `description` and `welcomeText`, so `tier` and `systems` physically cannot
   live in the output. **`config.templates` is the registry;
   `config.flake.templates` is the output.** One word apart.
3. **Every template directory is registered; every registry entry has a
   directory.** Checked.
4. **A template's only input is nixpkgs, and it iterates systems itself** —
   a four-line `forAllSystems` over `nixpkgs.lib.genAttrs`, with the `systems`
   list written out and checked against the registry. Never introduce
   `flake-utils`, flake-parts, import-tree, devenv or snowfall *into a
   template*. A template must be readable by someone who has never seen this
   repo. All five are checked; `docs/decisions/no-flake-utils.md`,
   `docs/decisions/devenv.md`.
5. **One nixpkgs spelling:** `github:nixos/nixpkgs/nixos-unstable`. Checked.
6. **Every template ships `.editorconfig`, `.envrc`, `.gitignore`, `README.md`
   and a `description`.** The `.gitignore` opens with the four-line Nix block;
   the README opens with `# <template-name>` and has a `## Building` section;
   the `description` equals the registry's. All checked.
7. **`meta/` is flake-parts; templates are not.** The two never mix.

## 2. Mental model

Two layers that must not bleed into each other.

**The registry** (`meta/`) is this repo's own flake — flake-parts, one lock, one
nixpkgs. It exists to *describe and test* the templates. `flake.templates` is
`mapAttrs` over `config.templates`; adding a registry entry is what publishes a
template.

**The templates** are eleven unrelated flakes that happen to live in one git
repo. They share no code and cannot. They are the artifact.

flake-parts is used **only** for the registry, and only because `perSystem` is
what makes a `checks` output practical. The dendritic pattern is not used: it
solves cross-cutting merge (*many files → one aspect*), and a template maps 1:1
to exactly one registry entry — there is nothing to merge. Revisit only if
templates ever contribute a second output class (a NixOS module, a docs page).

## 3. Tiers

Every registry entry declares how far the harness goes. Tier is a statement
about what is *provable in CI*, not about template quality.

| Tier | Runs |
| --- | --- |
| `eval` | instantiate, then `nix flake check --no-build` |
| `shell` | the above, then `nix develop --command` each `smoke` command |
| `build` | the above, then `nix build .#default` (the template's own `doCheck` runs here) |

**A tier below `build`, or a narrowed `systems`, requires a `reason`.** Checked.
The reason is the thing a future reader needs: *why* this template cannot be
proven further. "unfree Android SDK; gradle build needs network" is a reason;
"eval only" is not.

Raising a tier is a real improvement and always welcome. Lowering one to make CI
green is how a repo starts lying about itself — fix the template instead, or add
a `§7` divergence.

## 4. Layout

```
flake.nix                 # inputs + mkFlake + imports = [ ./meta ]. Rarely touched.
meta/
  registry.nix            # the option type; derives flake.templates
  templates.nix           # THE list — one block per template
  checks.nix              # static checks (see §6)
  harness.nix             # packages.registry-json, apps.test
  dev.nix                 # devShell + formatter
scripts/test-template.sh  # the real test harness
templates/<name>/         # one directory per template, standalone, self-contained
docs/decisions/           # why a call was made
```

**Everything under `templates/` is a template, and nothing else lives there.**
That is what lets `registry-bijection` read the directory listing straight,
with no denylist of repository machinery to keep in step — before the split it
carried one, and any new top-level directory failed the check until someone
remembered to extend it.

`meta/` uses a plain `imports` list. There is no `import-tree` here and adding
one is not an improvement at six files.

## 5. Lock policy — hybrid

| Locked (committed `flake.lock`) | Unlocked |
| --- | --- |
| — none today | all eleven |

Unlocked so consumers get current nixpkgs on first use. The bar for locking is
resolution being slow or fragile, and **nothing meets it right now** —
`android-kotlin` was the last locked template and its pin bought little: it was
`tier = "eval"` at the time, so what the lock froze was an evaluation the weekly
cron re-runs anyway.

The policy stays a hybrid rather than "everything unlocked": the `locked` field,
the `.gitignore` negation mechanism and the `lock-policy` check all remain, so
the next slow-resolving template does not have to reintroduce them. Locking one
is a small change and the **update-locks** skill spells it out.

Consequences, both of which bite:

- **An unlocked template can break with no commit in this repo.** A red harness
  run may be upstream drift. Triage before editing — §6. With nothing locked,
  the weekly scheduled run is the *only* thing between upstream drift and a
  consumer finding it.
- **Updating a locked template's lock changes what consumers get.** It is a
  consumer-facing change and belongs in its own commit with a rationale. Bare
  `nix flake update` is hook-blocked — it would also move the root lock, which
  is tracked.

`.gitignore` ignores `flake.lock` repo-wide and re-includes exactly one: the
root's, which belongs to this repo's own flake. Locking a template means adding
a negation line.

## 6. Hazards and verification

- **`git add -A` before every `nix` command.** Flakes see only tracked files, so
  a newly written template file is invisible to `nix flake init -t .#foo` — and
  the failure looks like a missing file, not an unstaged one. Hook enforced.
- **`nix flake check` does not test templates.** It validates *this* flake and
  the shape of the `templates` output. It never evaluates a template's own
  flake. Only `scripts/test-template.sh` does that.
- **`checks` cannot instantiate a template.** `recursive-nix` is not enabled and
  the build sandbox has no network: a derivation cannot run `nix flake init` or
  `nix develop`. This is why the harness is a script and not a check. Do not
  move it. `.claude/rules/harness.md`.
- **Do not claim a template works without having run the harness on it.**
  Reading a flake is not evidence.
- **flake-parts at the root costs the consumer a fetch.** Nix resolves every
  root input before evaluating `outputs`, so `nix flake init -t
  github:Marcus441/nix-templates#shell` now pulls flake-parts and nixpkgs before
  printing anything. Accepted knowingly — `docs/decisions/flake-parts-at-root.md`
  — so do not "optimise" it away by moving the registry into a second flake.
- **`templates/android-kotlin/.github/workflows/ci.yml` is payload,** shipped inside the
  template so generated repos inherit it. GitHub runs only root workflows, so it
  has never run here. Do not consolidate it. `.claude/rules/ci.md`.
- **A broad `treefmt` exclusion hides a template from the formatter.**
  `android-kotlin/**` was once excluded alongside `**/gradlew*` and
  `**/gradle/**`, which already kept shfmt off the vendored Gradle wrapper — so
  it bought nothing, and silently exempted that template's `flake.nix` from
  alejandra for as long as it existed. `checks.treefmt` stayed green because it
  was not looking. Both the wrapper and the exclusions are gone, and `*.lock` is
  the only global exclusion left. Scope any new one to the files that need it.

```bash
git add -A && nix flake check      # static layer — seconds
./scripts/test-template.sh         # the real proof — full table
./scripts/test-template.sh --keep rust   # debug one failure
```

## 7. Known divergences

**A ratchet, not a ledger:** if a task touches a file listed here, migrate it in
the same change, or state why not. Item numbers are stable identities — closed
items are deleted and survivors keep their numbers.

4. **The four C++ templates duplicate each other by design.** `cpp-prod` and
   `cpp-prod-modern` are the worst pair — near-identical `CMakeLists.txt`,
   `CMakePresets.json` and `.github/workflows/ci.yml`, differing only in the
   module handling — and all four repeat the toolchain scaffold in `flake.nix`.
   Inv. 1 forbids extracting any of it. The ladder is worth the cost, but a fix
   to one rung is worth applying to the others, and `cpp-prod-modern`'s README
   points at `cpp-prod` rather than restating its reasoning.
9. **Only `x86_64-linux` is provable locally.** CI covers all three systems a
   template can claim, but `./scripts/test-template.sh` runs on the machine you
   are sitting at — so a template authored on Linux cannot be verified for
   `aarch64-darwin` or `aarch64-linux` without pushing. Expect the first CI run
   on a new template to find things the harness could not.
10. **The harness's own bash 3.2 compatibility is unprovable locally.** The
    macOS runners ship bash 3.2.57 and nixpkgs has no 3.2 to test against, so
    the constraints in `.claude/rules/harness.md` are held by review and by the
    darwin legs going green — nothing checks them before a push.

## 8. Anti-patterns

| Anti-pattern | Why |
| --- | --- |
| flake-utils / flake-parts / import-tree / devenv / snowfall inside a template | Inv. 4 — a template must read standalone, on one input. Checked |
| A comment in a template's `flake.nix` | It belongs in that template's README — `.claude/rules/template-flake-conventions.md` |
| A `shellHook` that only prints a banner | A subprocess on every `nix develop` and every direnv reload, for what the README already says |
| `buildInputs` / `nativeBuildInputs` in a `mkShell`, or a bare `FOO = "…"` env var | One spelling per job: `packages` and `env = {…}` |
| A `systems` list that disagrees with the registry | Inv. 4 — the template would claim a platform nothing tests |
| A template importing `../` or `../../shared` | Inv. 1 — the copy would dangle |
| A template that ships an application architecture | It ships an environment; the project comes from the ecosystem's own scaffolder — `docs/decisions/environment-not-project.md` |
| Hand-written `flake.templates` | Inv. 2 — it is derived |
| Extracting a shared `lib/` for templates to import | Inv. 1 — impossible, not merely discouraged |
| `nix flake init`/`nix develop` inside a `checks` derivation | No recursive-nix, no network (§6) |
| A fourth nixpkgs URL spelling | Inv. 5 |
| A new template directory with no registry entry | Inv. 3 |
| Lowering a tier to make CI green | §3 — the repo stops describing itself |
| `tier = "eval"` with no `reason` | §3, and the check rejects it |

## 9. Working style

- **Branch first. Never commit to `main`.** `nix flake init -t
  github:Marcus441/nix-templates#<name>` resolves the *default branch*, so a
  commit on `main` is published to every consumer the moment it is pushed —
  there is no release step between the two, and no way to stage a change for
  review afterwards. Cut a branch before the first edit and open a PR, so CI
  runs the matrix on all three systems before anything reaches a consumer. This
  matters most for exactly the changes that feel safe enough to skip it: a
  rename breaks every init command in the wild, and an unlocked template's
  breakage shows up in someone else's project, not here. Branch names follow
  the commit scope: `feat/…`, `fix/…`, `refactor/…`, `docs/…`.
- **Small, single-concern commits.** Conventional-commit style with a scope,
  matching existing history: `feat(rust):`, `fix(ci):`, `docs(android):`.
- **Rationale in the commit message,** not in comments. A decision that recurs
  goes in `docs/decisions/`.
- **Adding a template is one move** — use the **add-template** skill. Directory,
  standalone flake, `.editorconfig`/`.envrc`/`.gitignore`/README, registry entry
  with tier and reason, then run the harness.
- **No unrequested changes.** No package bumps, no nixpkgs bumps, no
  reformatting a template the current task does not touch. A template someone
  depends on is not a scratchpad.
- **Do not introduce a framework** (devenv, snowfall, flake-file, numtide
  blueprint) without being asked — into the registry or into a template.
- **Do not re-propose:** the dendritic pattern for this repo (§2); a shared
  library for templates (Inv. 1 makes it impossible); moving
  `templates/android-kotlin/.github/workflows/ci.yml` to the repo root — it lives inside
  the template *so generated repos inherit it*, and has never run here;
  reintroducing `flake-utils` to shorten the `forAllSystems` helper — the
  duplication is the design, `docs/decisions/no-flake-utils.md`; devenv in a
  template or in the registry, including a hybrid `.envrc` —
  `docs/decisions/devenv.md`; pinning `android-kotlin`'s Android SDK with
  `androidenv`, or shipping a sample app it could generate —
  `android create` needs a *writable* SDK and refuses a non-empty directory,
  `docs/decisions/android-cli.md`; reinstating `ts-node-rest-api`, or any
  template whose only difference from an existing one is its dependencies and
  file layout, and a services or full-stack template *in this repo* — the
  harness has no service lifecycle to prove one with,
  `docs/decisions/environment-not-project.md`.
- **If a request genuinely doesn't fit,** say so and give options with their
  costs. Do not silently bend an invariant.

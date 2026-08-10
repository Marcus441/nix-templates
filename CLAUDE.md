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
4. **Templates use plain `flake-utils`.** Never introduce flake-parts,
   import-tree, devenv or snowfall *into a template*. A template must be
   readable by someone who has never seen this repo.
5. **One nixpkgs spelling:** `github:nixos/nixpkgs/nixos-unstable`. Checked.
6. **Every template ships `.envrc`, `.gitignore`, `README.md` and a
   `description`.** Checked.
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
<template>/               # one directory per template, standalone, self-contained
docs/decisions/           # why a call was made
```

`meta/` uses a plain `imports` list. There is no `import-tree` here and adding
one is not an improvement at six files.

## 5. Lock policy — hybrid

| Locked (committed `flake.lock`) | Unlocked |
| --- | --- |
| `android-kotlin`, `cpp-jetson`, `python-jetson` | the other eight |

Locked where resolution is slow or fragile. Unlocked elsewhere so consumers get
current nixpkgs on first use.

Consequences, both of which bite:

- **An unlocked template can break with no commit in this repo.** A red harness
  run may be upstream drift. Triage before editing — §6.
- **Updating a locked template's lock changes what consumers get.** It is a
  consumer-facing change and belongs in its own commit with a rationale. Bare
  `nix flake update` is hook-blocked.

`.gitignore` ignores `flake.lock` repo-wide and re-includes the four that are
tracked (the three above plus the root's). Adding a locked template means adding
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
- **`android-kotlin/.github/workflows/ci.yml` is payload,** shipped inside the
  template so generated repos inherit it. GitHub runs only root workflows, so it
  has never run here. Do not consolidate it. `.claude/rules/ci.md`.

```bash
git add -A && nix flake check      # static layer — seconds
./scripts/test-template.sh         # the real proof — full table
./scripts/test-template.sh --keep rust   # debug one failure
```

## 7. Known divergences

**A ratchet, not a ledger:** if a task touches a file listed here, migrate it in
the same change, or state why not. Item numbers are stable identities — closed
items are deleted and survivors keep their numbers.

1. **Both jetson templates are `broken = true`** — `packages.<system>.arm64.app`
   nests one level deeper than the flake schema allows, and
   `python-jetson/pyproject.toml` is empty. Issue #1. They report XFAIL, so
   nothing about them is proven beyond the dev shell.
2. **`cpp-jetson` and `python-jetson` duplicate ~20 lines verbatim** — the
   l4t-base container block, its digest and sha256. Inv. 1 forbids extracting
   them; the duplication is permanent and must stay in sync by hand.
4. **`cpp` and `cpp-modern` share ~45 lines** of toolchain scaffold. Same
   constraint as item 2.
6. **No macOS CI.** `systems` includes `aarch64-darwin` but nothing proves it,
   so a darwin-only breakage would ship.
7. **`node-rest-api` ships no lock despite pinned npm dependencies.** Its
   `package.json` pins Express 5 and vitest 3, but the dev shell only provides
   Node — so `npm install` resolves fresh and the template is only as
   reproducible as the registry it hits.

## 8. Anti-patterns

| Anti-pattern | Why |
| --- | --- |
| flake-parts / import-tree inside a template | Inv. 4 — a template must read standalone |
| A template importing `../` or `../../shared` | Inv. 1 — the copy would dangle |
| Hand-written `flake.templates` | Inv. 2 — it is derived |
| Extracting a shared `lib/` for templates to import | Inv. 1 — impossible, not merely discouraged |
| `nix flake init`/`nix develop` inside a `checks` derivation | No recursive-nix, no network (§6) |
| A fourth nixpkgs URL spelling | Inv. 5 |
| A new template directory with no registry entry | Inv. 3 |
| Lowering a tier to make CI green | §3 — the repo stops describing itself |
| `tier = "eval"` with no `reason` | §3, and the check rejects it |

## 9. Working style

- **Small, single-concern commits.** Conventional-commit style with a scope,
  matching existing history: `feat(rust):`, `fix(ci):`, `docs(android):`.
- **Rationale in the commit message,** not in comments. A decision that recurs
  goes in `docs/decisions/`.
- **Adding a template is one move** — use the **add-template** skill. Directory,
  standalone flake, `.envrc`/`.gitignore`/README, registry entry with tier and
  reason, then run the harness.
- **No unrequested changes.** No package bumps, no nixpkgs bumps, no
  reformatting a template the current task does not touch. A template someone
  depends on is not a scratchpad.
- **Do not introduce a framework** (devenv, snowfall, flake-file, numtide
  blueprint) without being asked — into the registry or into a template.
- **Do not re-propose:** the dendritic pattern for this repo (§2); a shared
  library for templates (Inv. 1 makes it impossible); moving
  `android-kotlin/.github/workflows/ci.yml` to the repo root — it lives inside
  the template *so generated repos inherit it*, and has never run here.
- **If a request genuinely doesn't fit,** say so and give options with their
  costs. Do not silently bend an invariant.

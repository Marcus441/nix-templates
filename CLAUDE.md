# CLAUDE.md — flake templates

This repository publishes **project templates** consumed by
`nix flake init -t github:Marcus441/nix-templates#<name>`. Its product is not a
configuration — it is twelve standalone projects that other people copy: eleven
flakes, and one devenv environment. That one fact drives every rule below. If a
change would violate an invariant, stop and say so.

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
4. **A template declares its `kind`, and the kind decides its shape.**
   `kind = "flake"` — eleven of the twelve, and the default — means **one input,
   nixpkgs**, and a four-line `forAllSystems` over `nixpkgs.lib.genAttrs` with
   the `systems` list written out and checked against the registry. Never
   introduce `flake-utils`, flake-parts, import-tree, devenv or snowfall *into
   a flake template*. All five are checked; `docs/decisions/no-flake-utils.md`.

   `kind = "devenv"` means **`devenv.nix` and `devenv.yaml` and no `flake.nix`
   at all** — native devenv, never the flake integration, which cannot start
   processes. `devenv.yaml` pins the same nixpkgs spelling and neither file may
   reach outside the template directory; both checked by `devenv-inputs`.
   `docs/decisions/devenv-templates.md`.

   Either way a template must be readable by someone who has never seen this
   repo. Note one asymmetry: a devenv template has no `systems` of its own, so
   its platform claim is enforced by the CI matrix alone, not by its artifact.
5. **One nixpkgs spelling:** `github:nixos/nixpkgs/nixos-unstable`. Checked.
6. **Every template ships `.editorconfig`, `.envrc`, `.gitignore` and
   `README.md`, plus the artifact its kind calls for** — `flake.nix` with a
   `description` equal to the registry's, or `devenv.nix` and `devenv.yaml`.
   The `.gitignore` opens with the four-line Nix block and the README opens
   with `# <template-name>` and has a `## Building` section, both regardless of
   kind. Shipping the *other* kind's artifact is a failure too: one environment,
   one definition of it. All checked.
7. **`meta/` is flake-parts; templates are not.** The two never mix.

## 2. Mental model

Two layers that must not bleed into each other.

**The registry** (`meta/`) is this repo's own flake — flake-parts, one lock, one
nixpkgs. It exists to *describe and test* the templates. `flake.templates` is
`mapAttrs` over `config.templates`; adding a registry entry is what publishes a
template.

**The templates** are twelve unrelated projects that happen to live in one git
repo — eleven flakes and one devenv environment. They share no code and cannot.
They are the artifact.

The second kind arrived in `docs/decisions/devenv-templates.md`, and it is the
"second output class" this section used to name as the trigger for revisiting
the dendritic pattern. It is not one: a devenv template still maps 1:1 to
exactly one registry entry, so there is still nothing to merge. What it did
change is that every check reading a template's *source* must branch on
`kind` — because a template with no `flake.nix` is an eval error, not a failed
check, and it takes `nix flake show` down for the whole repo.

flake-parts is used **only** for the registry, and only because `perSystem` is
what makes a `checks` output practical. The dendritic pattern is not used: it
solves cross-cutting merge (*many files → one aspect*), and a template maps 1:1
to exactly one registry entry — there is nothing to merge. Revisit only if a
template ever contributes a genuine second output class (a NixOS module, a docs
page) — a second *kind* is not that, as above.

## 3. Tiers

Every registry entry declares how far the harness goes. Tier is a statement
about what is *provable in CI*, not about template quality.

Every tier instantiates first, with `nix flake init -t` — for both kinds; it is
a directory copy and works on a template with no `flake.nix`. What follows
depends on the kind.

| Tier | `kind = "flake"` | `kind = "devenv"` |
| --- | --- | --- |
| `eval` | `nix flake check --no-build` | `devenv info` |
| `shell` | the above, then `nix develop --command` each `smoke` command | the above, then `devenv shell --` each `smoke` command |
| `build` | the above, then `nix build .#default` — **sandboxed, no network** (the template's own `doCheck` runs here) | the above, then `devenv test` — starts the declared processes, runs `enterTest`, stops them. **Not sandboxed; has network** |

The two `build` columns are not the same claim, which is why they are written
out. A green flake `build` says the package builds hermetically; a green devenv
`build` says the services actually came up and answered. More evidence about
one thing, less about the other.

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
.githooks/                # commit-msg, pre-push; core.hooksPath, set by the dev shell
templates/<name>/         # one directory per template, standalone, self-contained
                          #   kind=flake:  flake.nix + the four dotfiles
                          #   kind=devenv: devenv.nix + devenv.yaml + the same four
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

`.gitignore` ignores `flake.lock` and `devenv.lock` repo-wide and re-includes
exactly one: the root's `flake.lock`, which belongs to this repo's own flake.
Locking a template means adding a negation line for whichever lock its kind
uses; `lock-policy` branches on `kind` and checks the right filename.

**A devenv template has a wider drift surface than a flake one, and the
artifact does not show it.** `devenv.yaml` declares nixpkgs; devenv adds itself
as a second input, and `devenv.lock` pins both. Unlocked, the template
therefore tracks `cachix/devenv` — so its *service modules* move, not just its
packages, and nothing in the template mentions the input responsible.
`devenv-postgres` broke exactly this way during development, between one day
and the next, with no commit on either side. That makes a devenv template the
first real candidate for `locked = true` under this section's "slow or
fragile" bar.

## 6. Hazards and verification

- **`git add -A` before every `nix` command.** Flakes see only tracked files, so
  a newly written template file is invisible to `nix flake init -t .#foo` — and
  the failure looks like a missing file, not an unstaged one. Hook enforced.
- **Therefore commit with an explicit pathspec: `git commit -- <paths>`.** The
  same hook stages the *whole* working tree on any command mentioning nix or
  `test-template.sh`, including changes that are not yours, so by the time you
  commit the index is not a record of what you meant to include. A pathspec
  commits those paths whatever the index holds. Without one, a nine-file change
  has gone in as thirty-three. Run `git status` first and confirm every
  modified file is yours; if one is not, leave it and say so.
- **A `devenv` run inside a template directory leaves `.devenv/` behind, and
  the pre-nix hook will stage it.** `.claude/hooks/git-add-before-nix.sh` does
  not match a bare `devenv` command, so nothing is staged at that moment — the
  *next* `nix` command in the session sweeps the whole tree, and `.devenv/`
  holds a live postgres data directory. The root `.gitignore` covers it; do not
  remove those lines.
- **The harness resolves `devenv` itself.** `nix run --inputs-from "$REPO"
  nixpkgs#devenv` when it is not already on `PATH`, so CI needs no install
  step. Two reasons it is written that way: a bare `nixpkgs#devenv` would
  resolve the *caller's* flake registry, which is a fourth nixpkgs spelling
  arriving through the back door; and `nix flake check` realises `devShells`,
  so putting devenv in the dev shell would put its 394 MiB closure on the
  `static` job on every push.
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
| flake-utils / flake-parts / import-tree / devenv / snowfall inside a `kind = "flake"` template | Inv. 4 — a flake template must read standalone, on one input. Checked |
| A `kind = "devenv"` template that also ships a `flake.nix` — or the reverse | Two definitions of one environment with nothing checking they agree. The hybrid `docs/decisions/devenv.md` rejected; now checked |
| devenv's *flake integration* (`devenv.lib.mkShell`) in any template | It cannot start processes, and needs `--no-pure-eval` — every cost, none of the benefit. `docs/decisions/devenv-templates.md` |
| A `shellHook` in a devenv template's `devenv.nix` that only prints a banner | Same rule as a flake's `shellHook`, same reason |
| A comment in a template's `flake.nix` or `devenv.nix` | It belongs in that template's README — `.claude/rules/template-flake-conventions.md`, `.claude/rules/template-devenv-conventions.md` |
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
  the commit scope: `feat/…`, `fix/…`, `refactor/…`, `docs/…`. Rebase onto
  `main` before opening the PR if it has diverged, and never force-push a
  branch someone else may have pulled — `pre-push` refuses that for `main` and
  `master`, but it cannot know who is watching a feature branch.
- **A PR is reviewable in one sitting, or it is two PRs.** Title follows the
  commit-subject convention. The description is one sentence of *why*, then dot
  points covering the decisions — not a narration of the diff, which the files
  tab already shows. If it will be squash-merged, that description **is** the
  squash commit body, so write it as one.
- **Small, single-concern commits.** One logical change each: if the subject
  wants the word "and", it is probably two commits. The reverse is not a
  licence to split — a change touching twelve files for one reason is still one
  commit, and a long body is never a reason to break it into an incoherent
  history. Keep a reformat or a rename out of a commit that changes behaviour;
  they are separately reviewable and mixing them makes neither reviewable.
- **The mechanical half is `.githooks/commit-msg`,** so it is not restated here:
  subject shape and length, imperative mood, contentless subjects and body
  width. It runs from `core.hooksPath`, which is per-clone local config — the
  dev shell sets it, so a checkout that never enters the shell has no hooks.
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
  duplication is the design, `docs/decisions/no-flake-utils.md`; a **hybrid
  `.envrc`** (`use devenv` with a `use flake` fallback), devenv's **flake
  integration** in any template, and devenv inside a `kind = "flake"` template
  — all three still rejected, `docs/decisions/devenv.md` and
  `docs/decisions/devenv-templates.md`, and the first two are now checked;
  a **second `devenv-templates` repository**, which would mean maintaining two
  harnesses so that one enum could stay an enum of one; pinning
  `android-kotlin`'s Android SDK with
  `androidenv`, or shipping a sample app it could generate —
  `android create` needs a *writable* SDK and refuses a non-empty directory,
  `docs/decisions/android-cli.md`; reinstating `ts-node-rest-api`, or any
  template whose only difference from an existing one is its dependencies and
  file layout. A services or full-stack template *in this repo* is no longer on
  this list: `devenv test` gave the harness the service lifecycle it lacked, and
  `docs/decisions/devenv-templates.md` records the decision. What survives from
  `docs/decisions/environment-not-project.md` is the rule that outlived it — a
  template ships an environment, not a project — and it binds a devenv template
  exactly as it binds a flake one.
- **If a request genuinely doesn't fit,** say so and give options with their
  costs. Do not silently bend an invariant.

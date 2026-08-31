---
description: >-
  Use when adding a new project template to this repository, or when renaming or
  removing one. Covers the directory contents, the devenv environment, the
  registry entry with its tier and reason, the lock decision, and the harness
  run that has to pass before it ships.
---

# Adding a template

Adding a template is one move, not five. A directory without a registry entry
gets no checks and no harness coverage; a registry entry without a directory
fails `nix flake check`.

## 1. The directory

`templates/<name>/` — the directory name is the template name, and the registry
derives `path` from it.

**There is no kind to decide.** A template *is* `devenv.nix` and `devenv.yaml`
plus the four dotfiles — native devenv, never the flake integration, and no
`flake.nix` at all: shipping one fails `template-hygiene`, because one
environment gets one definition. `docs/decisions/devenv-templates.md` has the
reasoning; `.claude/rules/template-devenv-conventions.md` has the conventions.

Six files are mandatory (Inv. 6, checked):

| File | Content |
| --- | --- |
| `devenv.nix` + `devenv.yaml` | The environment. `devenv.yaml` carries the canonical two-line nixpkgs input from the conventions doc — copy it exactly, indentation included; `devenv-inputs` matches whole lines. No comments in `devenv.nix`; they belong in the README. |
| `.editorconfig` | Copy the `[*]` block from `templates/cpp/.editorconfig` verbatim, then append only the block the language needs (4 spaces for Python/Kotlin/C#, a line length otherwise). No language block at all if 2 spaces is right. |
| `.envrc` | `eval "$(devenv direnvrc)"` then `use devenv` — not `devenv init`'s `source_url`, which pins a hash that rots |
| `.gitignore` | Must **open** with the four-line Nix block (`# Nix`, `result`, `result-*`, `.direnv/`), then `.devenv*` and `devenv.local.nix`, then the language's build output — but **not** `devenv.lock`, which the consumer commits |
| `README.md` | Opens with `# <name>`, and must have a `## Building` section — there is nothing to `nix build`, so it says what the build-shaped command is: `devenv test`. |

Copy from a model rather than from memory: `templates/rust` for a language
template, `templates/devenv-postgres` for one with a service, and
`docs/decisions/fullstack-monorepo-layout.md` for the layout a full-stack
template must follow.

Neither devenv file can reference anything outside the directory (Inv. 1) — no
`../`, checked in both. If it looks like it wants to share code with an
existing template, it can't — copy the code and record the duplication in
CLAUDE.md §7.

## 2. The registry entry

`meta/templates.nix`, alphabetical:

```nix
<name> = {
  description = "Dev environment for …";   # required, and unique
  tier = "build";                          # what CI can actually prove
  smoke = ["<tool> --version"];            # at tier >= shell
};
```

The registry is the **only** place `description` and `systems` live — no
artifact carries either, so there is nothing to keep in agreement with. What is
checked is uniqueness: a `description` copied from another template is the
cheapest signal that other lines were copied too (`description-unique`). A
narrowed `systems` is enforced by the CI matrix alone — the entry *is* the
platform claim.

Choose the **highest tier that honestly passes** (CLAUDE.md §3): `devenv info`,
then `devenv shell --` each `smoke` command, then `devenv test`:

- `build` — `enterTest` proves the environment: `devenv test` builds it, starts
  the declared processes, runs `enterTest` against them, stops them. Preferred,
  and the only rung that starts anything — a template below it proves almost
  nothing. Not sandboxed, and has network: a green `build` says the services
  came up and the tests passed, not that anything built hermetically.
- `shell` — the environment opens and the `smoke` commands run, but there is
  nothing for `enterTest` to build or exercise — typically a template that
  ships no project because the ecosystem's scaffolder generates it. Needs a
  `reason`.
- `eval` — `devenv info` resolves the module set and nothing more. Needs a
  `reason`, and usually narrowed `systems` too. Unfree is *not* a reason to sit
  here: `allowUnfree: true` in `devenv.yaml` is one line, and `android-kotlin`
  shows it.

`reason` is required below `build` or with narrowed `systems`, and must say *why
it cannot be proven further* — "ships no project — dotnet new scaffolds it, so
there is nothing for enterTest to build", not "eval only".

## 3. The lock decision

Default `locked = false`; the template resolves current nixpkgs on first use.

The lock is `devenv.lock`, and it covers more than `devenv.yaml` suggests:
devenv adds itself as a second input, so the lock pins the *service modules*
too. Unlocked, those float on `cachix/devenv` — `devenv-postgres` broke
overnight that way.

Set `locked = true` only when resolution is slow or fragile. No template meets
that bar today, so a new one almost certainly does not either — and being the
only locked template means being the only one the weekly drift run cannot speak
for. If it is warranted, also add the negation line to `.gitignore`:

```gitignore
!/templates/<name>/devenv.lock
```

generate the lock with `devenv update` in the template directory, and commit —
`lock-policy` enforces that the flag and the tracked file agree. CLAUDE.md §5.

## 4. Prove it

```bash
git add -A                              # flakes see only tracked files
nix flake check                         # static layer: registry, spelling, hygiene
./scripts/test-template.sh <name>       # the real proof
```

Both must be green before the template ships. Do not claim it works on the
strength of having read it. The harness resolves `devenv` itself when it is not
on `PATH`, so there is no setup beyond this.

## Renaming or removing

Renaming: rename the directory **and** the registry key together — `path` is
derived from the key, so a half-rename fails `nix flake check`. Consumers pin
the template name in their init command, so a rename is a breaking change worth
a note in the commit message.

Removing: delete the directory, the registry entry, any `.gitignore` negation,
and any CLAUDE.md §7 item that referenced it. If `defaultTemplate` in
`meta/registry.nix` pointed at it — it is `devenv` today, the stub a bare
`nix flake init` copies — repoint it.

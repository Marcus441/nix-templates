---
description: >-
  Use when adding a new project template to this repository, or when renaming or
  removing one. Covers the directory contents, the standalone flake, the
  registry entry with its tier and reason, the lock decision, and the harness
  run that has to pass before it ships.
---

# Adding a template

Adding a template is one move, not five. A directory without a registry entry
gets no checks and no harness coverage; a registry entry without a directory
fails `nix flake check`.

## 1. The directory

`<name>/` — the name is the template name, and the registry derives `path` from
it. Five files are mandatory (Inv. 6, checked):

| File | Content |
| --- | --- |
| `flake.nix` | Standalone. See `.claude/rules/template-flake-conventions.md` for the canonical preamble — copy it exactly, including the nixpkgs spelling, the `systems` list and the `...` ellipsis. |
| `.editorconfig` | Copy the `[*]` block from `cpp/.editorconfig` verbatim, then append only the block the language needs (4 spaces for Python/Kotlin/C#, a line length otherwise). No language block at all if 2 spaces is right. |
| `.envrc` | `use flake`, plus a `PATH_add` only where it earns one — `node_modules/.bin`, `build` |
| `.gitignore` | Must **open** with the four-line Nix block (`# Nix`, `result`, `result-*`, `.direnv/`), then the language's build output |
| `README.md` | Opens with `# <name>`, and must have a `## Building` section. `rust/README.md` is the model. |

The flake **cannot** reference anything outside this directory (Inv. 1). If it
looks like it wants to share code with an existing template, it can't — copy the
code and record the duplication in CLAUDE.md §7.

## 2. The registry entry

`meta/templates.nix`, alphabetical:

```nix
<name> = {
  description = "Dev environment for …";   # required, and the flake must match
  tier = "build";                          # what CI can actually prove
  smoke = ["<tool> --version"];            # at tier >= shell
};
```

`description` has to be **identical** to the one in the template's `flake.nix` —
`description-agrees` checks it. So does `systems`: whatever you put here has to
appear verbatim as the `systems` line in the flake.

Choose the **highest tier that honestly passes**:

- `build` — the template has a `packages.default` that builds in the sandbox,
  with no network. Preferred.
- `shell` — dev-shell-only template, or the package needs user scaffolding
  first. Needs a `reason`.
- `eval` — cross-compiled or network-dependent. Needs a `reason`, and usually
  `systems` and `locked` too. Unfree is *not* a reason to sit here: set
  `config.allowUnfree = true` in the flake's own `import nixpkgs` and the
  template evaluates purely.

`reason` is required below `build` or with narrowed `systems`, and must say *why
it cannot be proven further* — "unfree Android SDK; gradle build needs network",
not "eval only".

## 3. The lock decision

Default `locked = false`; the template resolves current nixpkgs on first use.

Set `locked = true` only when resolution is slow or fragile (the bar the three
existing locked templates meet). Then also add the negation line to
`.gitignore`:

```gitignore
!/<name>/flake.lock
```

and commit the lock. CLAUDE.md §5.

## 4. Prove it

```bash
git add -A                              # flakes see only tracked files
nix flake check                         # static layer: registry, spelling, hygiene
./scripts/test-template.sh <name>       # the real proof
```

Both must be green before the template ships. Do not claim it works on the
strength of having read it.

## Renaming or removing

Renaming: rename the directory **and** the registry key together — `path` is
derived from the key, so a half-rename fails `nix flake check`. Consumers pin
the template name in their init command, so a rename is a breaking change worth
a note in the commit message.

Removing: delete the directory, the registry entry, any `.gitignore` negation,
and any CLAUDE.md §7 item that referenced it. If `templates.default` pointed at
it, repoint `default` in `meta/registry.nix`.

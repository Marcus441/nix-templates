---
description: >-
  Use when testing a flake template in a sandbox — verifying that a template
  instantiates, that its dev shell opens, or that its package builds. Covers the
  harness CLI, what each tier proves, debugging a failure with --keep, and
  telling a template bug apart from upstream nixpkgs drift. Use after changing
  any template, before claiming a template works, and when a CI run goes red.
---

# Testing a template

`nix flake check` does **not** test templates — it validates this repo's flake
and the shape of the `templates` output, and never evaluates a template's own
flake. Only the harness does that.

```bash
./scripts/test-template.sh              # every template, at its declared tier
./scripts/test-template.sh rust cpp     # only these
./scripts/test-template.sh --list       # the registry as a table
./scripts/test-template.sh --tier eval  # cap everything at eval (fast sweep)
./scripts/test-template.sh --keep rust  # leave the temp dir for debugging
```

For each template the harness makes a temp dir, runs `nix flake init -t
.#<name>`, `git init && git add -A`, then runs the tier's steps.

## What a result means

| | Meaning |
| --- | --- |
| `PASS` | Everything the tier covers succeeded. **It does not mean the template is good** — see the tier table. |
| `FAIL` | Prints the temp dir and the exact failing command. Reproduce before theorising. |
| `SKIP` | The template's `systems` excludes this machine. Not a pass; nothing ran. |

Tiers (CLAUDE.md §3): `eval` instantiates and evaluates; `shell` also opens the
dev shell and runs each `smoke` command; `build` also runs `nix build .#default`,
which is where the template's own `ctest` / `cargo test` runs.

So a `PASS` at `eval` proves only that the flake evaluates — `android-kotlin` is
the only template there, and nothing proves its shell works. Say so rather than
reporting a bare green.

## Debugging a failure

```bash
./scripts/test-template.sh --keep <name>   # prints the temp dir it kept
cd /tmp/tmpl-<name>-XXXXXX
nix flake check --no-build                 # or whichever command failed
```

The temp dir is a real git repo with the template already staged, so you can
edit and re-run there — but **the fix goes in the template**, not in the copy.
Re-run the harness afterwards; the copy proves nothing.

## Is it the template, or upstream?

Eight templates are unlocked (CLAUDE.md §5), so they resolve nixpkgs fresh and
can break with no commit in this repo. Check before editing:

```bash
cd /tmp/tmpl-<name>-XXXXXX
nix flake check --no-build --override-input nixpkgs github:nixos/nixpkgs/<known-good-rev>
```

- **Passes with the pin** → upstream drift. Fix the template (adapt to the
  change, or give it a lock and set `locked = true`). Never fix the harness, and
  never lower the tier.
- **Fails with the pin** → the template. Ordinary bug.

## Before you report

- **`git add -A` first.** Flakes see only tracked files; the hook does this, but
  an untracked new file is still the most common cause of a phantom failure.
- Quote the actual table. Do not summarise a run you did not do — reading a
  flake is not evidence that it instantiates.
- A raised tier is worth mentioning; a lowered one needs a `reason` and a note
  in CLAUDE.md §7.

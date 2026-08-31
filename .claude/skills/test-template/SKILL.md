---
description: >-
  Use when testing a template in a sandbox — verifying that a template
  instantiates, that its shell opens, or that its services come up and pass
  enterTest. Covers the harness CLI, what each tier proves, debugging a failure
  with --keep, and telling a template bug apart from upstream drift. Use after
  changing any template, before claiming a template works, and when a CI run
  goes red.
---

# Testing a template

`nix flake check` does **not** test templates — it validates this repo's flake
and the shape of the `templates` output, and never runs a template's
environment. Only the harness does that.

```bash
./scripts/test-template.sh              # every template, at its declared tier
./scripts/test-template.sh rust cpp     # only these
./scripts/test-template.sh --list       # the registry as a table
./scripts/test-template.sh --tier eval  # cap everything at eval (see the note below)
./scripts/test-template.sh --keep rust  # leave the temp dir for debugging
```

For each template the harness makes a temp dir, runs `nix flake init -t
.#<name>` — a directory copy, the one flake-shaped step left — then `git init
&& git add -A`, then the tier's steps:

| Tier | Runs |
| --- | --- |
| `eval` | `devenv info` |
| `shell` | the above, then `devenv shell --` each `smoke` command |
| `build` | the above, then `devenv test` |

`--tier eval` is not a cheap sweep: `devenv info` has to resolve devenv's
module set, which is not fast on a cold cache. `devenv` itself is resolved by
the harness when it is not on `PATH`, so there is nothing to install first.

## What a result means

| | Meaning |
| --- | --- |
| `PASS` | Everything the tier covers succeeded. **It does not mean the template is good** — see the tier table. |
| `FAIL` | Prints the temp dir and the exact failing command. Reproduce before theorising. |
| `SKIP` | The template's `systems` excludes this machine. Not a pass; nothing ran. |
| `XFAIL` / `XPASS` | A template marked `broken` failing as expected, or starting to pass. An XPASS counts as a failure — drop the flag. |

`PASS` at `build` means `devenv test` built the environment, started the
declared processes and ran `enterTest` against them. It is not sandboxed and
has network — the hermetic `nix build` proof retired with the flake templates —
so a green `build` says the services came up and answered, and nothing about
hermeticity.

So a `PASS` at `eval` proves only that the module set evaluates, and nothing
proves the shell works. No template sits at `eval` today, so any new one that
does owes the reader that caveat rather than a bare green.

## Debugging a failure

```bash
./scripts/test-template.sh --keep <name>   # prints the temp dir and full log
cd /tmp/tmpl-<name>-XXXXXX
devenv info                                # or devenv test — whichever failed
```

The temp dir is a real git repo with the template already staged, so you can
edit and re-run there — but **the fix goes in the template**, not in the copy.
Re-run the harness afterwards; the copy proves nothing. If a manual `devenv
test` fails partway, `devenv processes down` in the copy stops whatever it left
running.

## Is it the template, or upstream?

Every template is unlocked (CLAUDE.md §5), so they all resolve fresh and can
break with no commit in this repo — and *two* inputs move, not one:
`devenv.yaml` names nixpkgs, and devenv adds itself as a second input, which is
where the service modules come from. Check before editing:

```bash
cd /tmp/tmpl-<name>-XXXXXX
devenv test -o nixpkgs github:nixos/nixpkgs/<known-good-rev>
```

- **Passes with the pin** → nixpkgs drift. Fix the template (adapt to the
  change, or give it a lock and set `locked = true`). Never fix the harness, and
  never lower the tier.
- **Fails with the pin** → the template, or module drift. Pin both inputs
  before concluding it is the template:

  ```bash
  devenv test -o nixpkgs github:nixos/nixpkgs/<rev> -o devenv github:cachix/devenv/<rev>
  ```

The revisions a working run used are in the `devenv.lock` that run wrote into
its copy — kept only under `--keep`, and the only place either is recorded.
Module drift is not hypothetical: `devenv-postgres` went from passing to
failing overnight on a `cachix/devenv` re-resolve, with no commit on either
side.

## Before you report

- **`git add -A` first.** Flakes see only tracked files; the hook does this, but
  an untracked new file is still the most common cause of a phantom failure.
- Quote the actual table. Do not summarise a run you did not do — reading a
  `devenv.nix` is not evidence that it instantiates.
- A raised tier is worth mentioning; a lowered one needs a `reason` and a note
  in CLAUDE.md §7.

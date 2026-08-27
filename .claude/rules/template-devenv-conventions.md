---
paths: "templates/*/devenv.nix"
---

# Writing a devenv template

A devenv template is read by someone who has never seen this repo, and copied
into a project that has no relationship to it. Optimise for that reader — the
same instruction as `.claude/rules/template-flake-conventions.md`, which is the
sibling document for `kind = "flake"`.

**There is no `flake.nix`, and there must not be one.** `template-hygiene`
fails a `kind = "devenv"` template that ships `flake.nix` or `flake.lock`, and
fails a flake template that ships `devenv.nix`, `devenv.yaml` or `devenv.lock`.
One environment, one definition of it — `docs/decisions/devenv.md` rejected the
hybrid and `docs/decisions/devenv-templates.md` did not reopen it.

**Never devenv's flake integration.** `devenv.lib.mkShell` inside a `flake.nix`
cannot start processes and needs `nix develop --no-pure-eval`. Since supervised
services are the only reason to reach for devenv here, that shape pays every
cost and delivers none of the benefit.

## The canonical `devenv.yaml`

```yaml
inputs:
  nixpkgs:
    url: github:nixos/nixpkgs/nixos-unstable
```

Both lines are matched whole by `devenv-inputs`, so the indentation is pinned
too. devenv's own default is `github:cachix/devenv-nixpkgs/rolling`; Inv. 5
says one spelling for this repo, so it has to be written out rather than
inherited.

## Rules

- **Never reference a path outside the template directory.** No `../`, in
  either file — a devenv template has one more way out than a flake does, and
  it is `imports = [ ../shared.nix ];` in `devenv.nix`. Checked in both files.
  `path:./sub` is fine: it stays inside the copy.
- **No comments in `devenv.nix`.** Same rule as a flake template's `flake.nix`,
  same reason: a reader skimming it should see the shape, not prose. Anything
  worth saying goes in the README under `Notes`. This matters more here, not
  less — a shim or a workaround needs a *removal trigger* a reader can act on,
  and a comment cannot carry one.
- **No `enterShell` banner.** A subprocess on every `devenv shell` and every
  direnv reload, for what the README already says. If it does real work it may
  stay; decoration may not.
- **`enterTest` must prove the service, not the binary.** `psql --version`
  proves nothing that a `smoke` command does not already prove. Wait for
  readiness, then exercise the thing: connect, write, read back. A green
  `build` tier for a devenv template is a claim that the services came up, so
  it has to be one.
- **Prefer a socket to a port.** `services.postgres` listens on a unix socket
  by default, which cannot collide with a service the developer already runs
  and keeps the path clear of the 104-byte limit macOS puts on `sun_path`.
  Setting `listen_addresses` is the consumer's choice to make, not the
  template's.
- **Track nixpkgs' default package, do not pin a major.** `services.<x>.package`
  is the knob, and the README should name it. Precedent: `4be382a`, which
  stopped pinning LLVM 18 for the same reason — a pinned major eventually
  leaves nixpkgs.
- **`unfree` goes in `devenv.yaml`, not the registry.** The registry's `unfree`
  flag adds `--impure` to a `nix` command; the harness refuses it outright for
  this kind rather than dropping it silently.
- **A shim for an upstream devenv bug needs a removal trigger in the README.**
  `devenv-postgres` is the worked example: devenv's own `services/postgres.nix`
  sets an option its `processes.nix` does not declare, so the template declares
  it — copied verbatim from devenv's own declaration in `tasks.nix`, so the two
  merge rather than collide when upstream adds it. Write the trigger as
  something a reader can *run*: delete the block, run `devenv test`, and if it
  passes the shim is obsolete.

## What a devenv template cannot do

**It cannot pin the thing most likely to break it.** `devenv.lock` pins
nixpkgs; devenv's service modules ship inside the binary the consumer
installed. When a devenv module breaks there is no in-template fix — which is
not true of any flake template, where `flake.lock` can pin everything. Say so
in the README rather than leaving it to be discovered.

**It has no `systems` of its own.** A flake template states its platform claim
in the artifact and `flake-inputs` greps for it. Here the claim lives only in
the registry and is enforced only by the CI matrix.

## Before you finish

- The template also needs `.editorconfig`, `.envrc` (`eval "$(devenv
  direnvrc)"` then `use devenv` — not `devenv init`'s `source_url`, which pins
  a hash that rots), `.gitignore` opening with the four-line Nix block, and a
  `README.md` opening with `# <name>` and carrying a `## Building` section.
  There is nothing to build, so that section says what the build-shaped command
  is: `devenv test`.
- The registry needs an entry with `kind = "devenv"` — see the **add-template**
  skill.
- **Run the harness.** `./scripts/test-template.sh <name>`. Reading the
  `devenv.nix` is not evidence that the service starts.

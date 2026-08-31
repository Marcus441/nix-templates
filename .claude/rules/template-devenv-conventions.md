---
paths: "templates/*/devenv.nix"
---

# Writing a template

A template is read by someone who has never seen this repo, and copied into a
project that has no relationship to it. Optimise for that reader.

**There is no `flake.nix`, and there must not be one.** `template-hygiene`
fails any template that ships `flake.nix` or `flake.lock`. One environment,
one definition of it — `docs/decisions/devenv.md` rejected the hybrid and
`docs/decisions/devenv-templates.md` did not reopen it.

**Never devenv's flake integration.** `devenv.lib.mkShell` inside a `flake.nix`
cannot start processes and needs `nix develop --no-pure-eval` — every cost of
the hybrid, none of the benefit.

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
  either file — `devenv.yaml`'s inputs are one way out of the copy, and
  `imports = [ ../shared.nix ];` in `devenv.nix` is the other. Checked in both
  files. `path:./sub` is fine: it stays inside the copy.
- **No comments in `devenv.nix`.** A reader skimming it should see the shape,
  not prose. Anything worth saying goes in the README under `Notes` — not
  least because a shim or a workaround needs a *removal trigger* a reader can
  act on, and a comment cannot carry one.
- **No `enterShell` banner.** A subprocess on every `devenv shell` and every
  direnv reload, for what the README already says. If it does real work it may
  stay; decoration may not.
- **`enterTest` must prove the service, not the binary.** `psql --version`
  proves nothing that a `smoke` command does not already prove. Wait for
  readiness, then exercise the thing: connect, write, read back. A green
  `build` tier is a claim that the services came up, so it has to be one.
- **Prefer a socket to a port.** `services.postgres` listens on a unix socket
  by default, which cannot collide with a service the developer already runs
  and keeps the path clear of the 104-byte limit macOS puts on `sun_path`.
  Setting `listen_addresses` is the consumer's choice to make, not the
  template's.
- **Track nixpkgs' default package, do not pin a major.** `services.<x>.package`
  is the knob, and the README should name it. Precedent: `4be382a`, which
  stopped pinning LLVM 18 for the same reason — a pinned major eventually
  leaves nixpkgs.
- **Never add a Nix language server to `packages`.** `devenv lsp` starts nixd
  already configured for `devenv.nix`, using the nixd bundled inside the devenv
  binary the consumer installed — `pkgs.nixd` would be a second copy in the
  closure for nothing. A template ships the *project's* language server, not
  one for its own build definition.
- **Check what a `languages.<x>.lsp.enable` default is computed from.** It is
  not always `true`, and it does not always track `lsp.package`.
  `languages.dotnet.lsp.enable` defaults to `availableOn <host> csharp-ls`, and
  `csharp-ls` sets `badPlatforms = ["aarch64-darwin"]` — so overriding only
  `lsp.package` leaves Apple Silicon with no server at all. Set `enable`
  explicitly when you override the package, and check the replacement is
  actually available on every system the registry claims.
- **Unfree or licence-gated packages: `allowUnfree: true` in `devenv.yaml`.**
  That is the whole mechanism — no registry flag, no `--impure`, nothing for
  the consumer to pass. `android-kotlin` is the worked example.
- **A shim for an upstream devenv bug is a liability with a short fuse.**
  `devenv-postgres` carried one for a day: devenv's `services/postgres.nix` set
  `processes.postgres.shutdown`, its `processes.nix` did not declare it, so the
  template declared it instead. The reasoning was that a declaration copied
  verbatim from devenv's own would *merge* when upstream added theirs. **It does
  not merge — the module system raises "is already declared in", and the shim
  broke the template the moment upstream fixed the bug.** Assume a shim will
  collide rather than merge, keep it to the smallest thing that works, and put a
  removal trigger in the README written as something a reader can run: delete
  the block, run `devenv test`, and if it passes the shim is obsolete.

  **Do not report it upstream.** Not an issue, not a pull request, not a draft
  offered for review — CLAUDE.md §9. A shim plus a removal trigger is the whole
  response.

## What the artifact does not say

**Unlocked, a template floats on an input it never declares.** `devenv.yaml`
names nixpkgs; devenv adds itself as a second input and `devenv.lock` pins
both. So an unlocked template tracks `cachix/devenv` and its *service modules*
move under it — a drift surface nothing in the template mentions.
`devenv-postgres` broke this way overnight during development. Say so in the
README, and suspect that input first when a template goes red with no commit
here.

**Every template's `systems` claim lives in the registry.** Neither
`devenv.nix` nor `devenv.yaml` names a platform, so `meta/templates.nix` is
the only place the claim exists and the CI matrix is its only enforcement.
Narrowing it there requires a `reason`.

## Before you finish

- The template also needs `.editorconfig`, `.envrc` (`eval "$(devenv
  direnvrc)"` then `use devenv` — not `devenv init`'s `source_url`, which pins
  a hash that rots), `.gitignore` opening with the four-line Nix block, and a
  `README.md` opening with `# <name>` and carrying a `## Building` section.
  There is no `nix build` here, so that section says what the build-shaped
  command is: `devenv test`.
- The registry needs an entry — see the **add-template** skill.
- **Run the harness.** `./scripts/test-template.sh <name>`. Reading the
  `devenv.nix` is not evidence that the service starts.

---
paths: "scripts/*"
---

# The harness — why it is a script and not a check

**Do not move template instantiation into a `checks` derivation.** It cannot
work, and the reason is not obvious enough to survive a well-meaning refactor.

A `nix build` sandbox has no network and no connection to the nix daemon, and
`recursive-nix` is **not** in this machine's `experimental-features`
(`fetch-tree flakes nix-command`). So a derivation cannot run `nix flake init`,
`nix flake check`, `nix develop` or `nix build`. Everything that proves a
template actually works has to happen outside the sandbox.

Hence the split:

| | `checks.*` (`meta/checks.nix`) | `scripts/test-template.sh` |
| --- | --- | --- |
| Runs | in the sandbox, under `nix flake check` | in your shell, and in CI |
| Can prove | facts about template *sources* — spellings, file presence, registry consistency | that a template instantiates, its shell opens, its package builds |
| Cost | seconds | minutes |

If a proposed check needs to *run* a template, it belongs in the script. If it
only needs to *read* the template's files or the registry, it belongs in
`checks.nix` and should go there — that layer is far cheaper.

## Writing the script

- **`git add -A` first, twice.** Once in this repo, so `nix flake init -t
  .#<name>` sees the template; once inside the freshly created temp repo, so its
  own flake sees the files that were just copied in. Both failures present as
  "path does not exist".
- **Tiers come from the registry**, via `nix build .#registry-json` and `jq`.
  The script must never hardcode a tier or re-parse Nix — `meta/templates.nix`
  is the single source of truth (CLAUDE.md Inv. 2).
- **`SKIP` is not `PASS`.** A template whose `systems` excludes the current
  system is skipped, and the summary must say so separately. A harness that
  reports green for work it did not do is worse than no harness.
- **Every `FAIL` prints a reproduce line and the failing command's output** —
  the temp dir, the exact command, and the last `LOG_TAIL` (default 40) lines.
  The reproduce line alone is useless on a CI runner nobody can `cd` into; a
  darwin failure that says only "FAIL" costs a whole round trip to diagnose.
  `--keep` suppresses cleanup so the directory and the full log both survive.
  Steps write to `"$work.log"` — *beside* the work directory, never inside it,
  or the template copy would `git add -A` a stray file into its own flake.
- **It must run on bash 3.2.** The macOS runners ship bash 3.2.57 and the
  workflow calls `./scripts/test-template.sh` directly, so the script gets the
  system bash, not a nixpkgs one. That rules out three things a Linux-only
  author will reach for without thinking:

  | Don't | Do |
  | --- | --- |
  | `mapfile -t arr < <(cmd)` | `arr=(); while IFS= read -r l; do arr+=("$l"); done < <(cmd)` |
  | `"${arr[@]}"` where `arr` may be empty | `${arr[@]+"${arr[@]}"}` — before 4.4 the first is an unbound variable under `set -u` |
  | `mktemp -d -t "pfx-XXXXXX"` | `mktemp -d "${TMPDIR:-/tmp}/pfx-XXXXXX"` — BSD `-t` takes a prefix, GNU `-t` a template |

  Also absent on 3.2: `declare -A`, `${var^^}` / `${var,,}`, `&>>`, `|&`.
  Running the script under `nix run .#test` would sidestep all of this, because
  `writeShellApplication` pins a modern bash — which is exactly why CI does
  *not* do that. Calling the script directly is what keeps the documented entry
  point honest on the machine a contributor actually has.

## Triage: template bug, or upstream drift?

Every template is unlocked (CLAUDE.md §5), so a red run may have nothing to do
with the current change. Before editing anything, re-run against a known-good
nixpkgs:

```bash
nix flake check --no-build --override-input nixpkgs github:nixos/nixpkgs/<rev>
```

Passes with the pin ⇒ upstream drift. The fix still belongs in the template
(pin it, or adapt to the change) — never in the harness, and never by lowering
the template's tier.

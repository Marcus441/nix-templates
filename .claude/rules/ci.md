---
paths: ".github/workflows/*"
---

# CI

Three things nothing else in the repo says.

## `android-kotlin/.github/workflows/ci.yml` is not this repo's CI

It is **payload**. It ships inside the template so that projects generated from
it inherit a working Android pipeline. GitHub only runs workflows found at the
repository root, so it has never executed here and never will. Moving it to the
root would break every generated project and test nothing. Commit `11d22e0`
moved it *into* the template deliberately.

## The matrix comes from the registry

`nix build .#registry-json`, then `jq`. Never a hand-written list of template
names — `meta/templates.nix` is the single source of truth (Inv. 2), and a
hand-maintained matrix is how a template silently stops being tested.

`nix-community/nix-github-actions` is deliberately unused: it derives a matrix
from the `checks` output, and this repo's checks are static and say nothing
about whether a template works. The `tier` decides *which commands run*, not
just which attribute to build, so the matrix has to carry it.

Templates whose `systems` excludes `x86_64-linux` are filtered out of the matrix
and listed in the job summary with their `reason` — visible, not silently
dropped.

## A red scheduled run usually is not the last commit

Eight templates ship unlocked, so the weekly cron tests today's nixpkgs against
last month's template. A failure there is upstream drift far more often than a
regression, and the `drift` job files or updates a single labelled issue rather
than leaving a red badge nobody watches.

Triage with `.claude/skills/test-template/SKILL.md` before editing anything. The
fix belongs in the template — never in the harness, and never by lowering a
tier.

## Caching

`nix-community/cache-nix-action`. Everything built here comes from
`cache.nixos.org`, so the cost is download, which the Actions store cache
removes. Cachix would need a secret and would break fork PRs for no benefit.
Keep `gc-max-store-size` set: the `cpp` and `rust` closures will otherwise
exhaust the 10 GB per-repository cache budget across eleven keys.

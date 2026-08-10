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

The matrix has two dimensions: template × runner. Every entry in a template's
`systems` produces a leg, so a system a template claims is a system something
tests:

| `systems` entry | Runner |
| --- | --- |
| `x86_64-linux` | `ubuntu-latest` |
| `aarch64-linux` | `ubuntu-24.04-arm` — free for public repositories only |
| `aarch64-darwin` | `macos-latest` |

`android-kotlin`, narrowed to `x86_64-linux`, gets one leg; everything else gets
three. 37 legs from 13 templates.

The runner list lives in the `RUNNERS` env of the `registry` job, and the job
summary prints any `systems` entry it does not cover. That list should stay
empty. **Adding a system to a template's `systems` without a runner for it is
how the repo goes back to claiming things nothing proves** — add the runner, or
do not make the claim.

Cache the `x86_64-linux` legs only. The Actions cache budget is 10 GB per
repository and the `cpp`/`rust` closures are large; caching all three runners
would triple the keys competing for it and evict each other. The other two legs
pay a download from `cache.nixos.org`. Cache keys carry `matrix.system` anyway,
so nothing collides if that decision is ever revisited.

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
exhaust the 10 GB per-repository cache budget across thirteen keys.

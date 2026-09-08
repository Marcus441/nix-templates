---
paths: ".github/workflows/*"
---

# CI

What nothing else in the repo says.

## `templates/*/.github/workflows/*.yml` is not this repo's CI

Fifteen workflow files across nine templates are **payload**. They ship inside
a template so that projects generated from it inherit a working pipeline —
`android-kotlin` a Gradle-and-emulator one, the other eight an
install-devenv-then-`devenv test` one, with the three full-stack templates
adding path-filtered `backend.yml` and `frontend.yml` beside their `ci.yml`.
`dotnet-angular-sqlserver`'s `ci.yml` is the one that runs on Linux alone
rather than Linux and macOS, because its `devenv test` needs a container
runtime the macOS runner does not have. GitHub only runs workflows found at
the repository root, so none of them has ever executed here and never will.
Moving one to the root would break every generated project and test nothing.
Commit `11d22e0` moved the android one *into* its template deliberately.

## `claude-code-review.yml` reviews, and only comments

The second workflow that runs here. It runs the `code-review` plugin against
every pull request and posts findings as inline comments on the diff;
`--allowedTools` grants exactly that one MCP tool, so the job can never push,
label or merge. It reviews against `CLAUDE.md` and `.claude/rules/` from the
checkout — so an invariant worth holding a PR to belongs in those files, not
in the workflow's prompt.

Two guards keep it from going red for reasons that are not the diff: a pull
request from a fork is skipped, because secrets are withheld from it and the
step would fail on a missing token rather than skip; and `concurrency` cancels
a review still in flight when the branch moves under it, which would otherwise
comment on lines the head no longer has. The `CLAUDE_CODE_OAUTH_TOKEN`
repository secret is what the whole thing hangs on.

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

`android-kotlin`, `devenv-sqlserver` and `dotnet-angular-sqlserver`, all
narrowed to `x86_64-linux`, get one leg each; everything else gets three.
42 legs from 16 templates.

The runner list lives in the `RUNNERS` env of the `registry` job, and the job
summary prints any `systems` entry it does not cover. That list should stay
empty. **Adding a system to a template's `systems` without a runner for it is
how the repo goes back to claiming things nothing proves** — add the runner, or
do not make the claim.

**The cache key hashes the template's `devenv.nix`, `devenv.yaml` and
`devenv.lock` in one `hashFiles`.** `devenv.lock` is listed although no
template ships one today: `hashFiles` returns `""` for a pattern matching
nothing rather than failing, so the key simply starts covering the lock when a
template locks. Listing the files rather than `templates/{0}/*` keeps a README
edit from churning the key.

Cache the `x86_64-linux` legs only. The Actions cache budget is 10 GB per
repository and the `cpp`/`rust` closures are large; caching all three runners
would triple the keys competing for it and evict each other. The other two legs
pay a download from `cache.nixos.org`. Cache keys carry `matrix.system` anyway,
so nothing collides if that decision is ever revisited.

## A red scheduled run usually is not the last commit

Every template ships unlocked, so the weekly cron tests today's nixpkgs against
last month's template — and with nothing pinned, that cron is the only thing
standing between upstream drift and a consumer finding it. A failure there is
upstream drift far more often than a regression, and the `drift` job files or
updates a single labelled issue rather than leaving a red badge nobody watches.

Triage with `.claude/skills/test-template/SKILL.md` before editing anything. The
fix belongs in the template — never in the harness, and never by lowering a
tier.

## Caching

`nix-community/cache-nix-action`. Everything built here comes from
`cache.nixos.org`, so the cost is download, which the Actions store cache
removes. Cachix would need a secret and would break fork PRs for no benefit.
Keep `gc-max-store-size` set: the `cpp` and `rust` closures will otherwise
exhaust the 10 GB per-repository cache budget across sixteen keys.

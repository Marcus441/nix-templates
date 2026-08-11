---
description: >-
  Use when deciding whether a template should be locked or unlocked, when
  updating a committed flake.lock (no template has one today), or when a
  scheduled CI run reports upstream nixpkgs drift.
---

# Lock policy

**No template ships a committed `flake.lock` today** (CLAUDE.md §5). All eleven
resolve current nixpkgs on first use, so there is no pin to bump — the sections
below describe what to do if one ever gets locked again, and the bar it has to
clear first.

The only tracked lock in the repository is the root's, which belongs to this
repo's own flake and reaches no consumer. Bare `nix flake update` is
hook-blocked because it moves every pin at once, that one included.

## The bar for locking

Resolution being slow or fragile — not "it broke once". An unlocked template
that breaks on drift is usually telling you the template needs fixing.

`android-kotlin` was the last locked template and no longer meets the bar: it was
`tier = "eval"` when locked, so the lock froze an evaluation that the weekly cron
re-runs anyway, at the cost of handing every consumer a nixpkgs that ages from
the day it was committed.

Locking is also a coverage decision, not only a speed one. A locked template is
one the drift run cannot speak for: it passes against its pin no matter what
upstream did.

## Locking a template

Set `locked = true` in `meta/templates.nix`, add `!/<name>/flake.lock` to
`.gitignore`, generate the lock with `nix flake lock` in the template directory,
and commit. The `lock-policy` check enforces that the flag and the tracked file
agree, so the two must move together.

## Unlocking a template

Reverse: drop `locked = true`, drop the negation line, and `git rm
<name>/flake.lock` — delete it rather than `--cached`, or a now-ignored lock
lingers in the working tree and keeps answering local `nix develop` runs long
after it stopped shipping.

The consumer then gets current nixpkgs, which means the weekly scheduled CI run
becomes the only thing standing between drift and a broken template. Make sure
that job is green first, and run `./scripts/test-template.sh <name>` unlocked
before committing — the point of the change is that it resolves fresh, so prove
that it does.

## Updating a lock

If a template is locked, one at a time, one commit each. Updating a lock is
**consumer-facing** — whoever runs `nix flake init -t` next gets exactly what
the update resolved. It is not housekeeping.

```bash
cd <template>
nix flake update nixpkgs        # name the input; bare update is blocked
cd .. && git add -A
./scripts/test-template.sh <template>
```

If the harness goes red, **revert the lock** rather than working around it:

```bash
git checkout -- <template>/flake.lock
```

A lock that does not pass its own tier must not ship. Then either fix the
template for the new nixpkgs, or leave the pin where it is and note why.

Commit as `build(<template>): bump nixpkgs pin`, with the rationale in the
message — what moved and why now.

## Drift from a scheduled run

A weekly run going red with no commits in between is drift by definition, and
with nothing pinned every template is exposed to it. Triage with the
**test-template** skill's pinned-nixpkgs check, then fix the template. Do not
silence it by lowering a tier, and do not silence it by locking the template —
that hides the drift instead of fixing it.

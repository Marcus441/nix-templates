---
description: >-
  Use when deciding whether a template should be locked or unlocked, when
  updating a committed devenv.lock (no template has one today), or when a
  scheduled CI run reports upstream drift.
---

# Lock policy

**No template ships a committed lock today** (CLAUDE.md §5). All fourteen
resolve current nixpkgs on first use, so there is no pin to bump — the sections
below describe what to do if one ever gets locked again, and the bar it has to
clear first.

One lock format: `devenv.lock`, written by `devenv update`. `lock-policy`
checks it against the `locked` flag, and `.gitignore` ignores it repo-wide,
re-included per template by a negation line. (`flake.lock` is ignored too, but
that is `template-hygiene`'s territory — no template may ship one at all.)

**A `devenv.lock` covers more than the template appears to depend on, and that
is the thing to know before leaving one unlocked.** `devenv.yaml` declares
nixpkgs; devenv adds *itself* as a second input, and the lock pins both. So an
unlocked template tracks `cachix/devenv` and its service modules move under
it — a drift surface nothing in the artifact mentions.

**This is the first thing in the repo's history with a real claim on
`locked = true`.** `devenv-postgres` went from passing to failing overnight on
a `cachix/devenv` re-resolve, with no commit on either side. The newest data
point landed during the devenv migration itself: `typst`'s `aarch64-darwin` leg
went red mid-CI-run on an upstream nixpkgs advance with no commit here, and
healed on re-run. §5's bar is "resolution being slow or fragile"; that is
fragile. Nothing has been locked yet — the weekly cron is currently what stands
in for it — but a second overnight break is the moment to stop arguing.

The only tracked lock in the repository is the root's `flake.lock`, which
belongs to this repo's own flake and reaches no consumer. Bare `nix flake
update` is hook-blocked because it moves every pin at once, that one included.

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

Set `locked = true` in `meta/templates.nix`, add the negation line to
`.gitignore` — `!/templates/<name>/devenv.lock` — generate the lock in the
template directory with `devenv update`, and commit. The `lock-policy` check
enforces that the flag and the tracked file agree, so the two must move
together.

## Unlocking a template

Reverse: drop `locked = true`, drop the negation line, and `git rm
templates/<name>/devenv.lock` — delete it rather than `--cached`, or a
now-ignored lock lingers in the working tree and keeps answering local `devenv`
runs long after it stopped shipping.

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
cd templates/<name>
devenv update                   # moves BOTH inputs — nixpkgs and devenv itself
cd ../.. && git add -A
./scripts/test-template.sh <name>
```

`devenv update` re-resolves the lock as a whole, service modules included, so
read the `devenv.lock` diff before committing and name what actually moved.

If the harness goes red, **revert the lock** rather than working around it:

```bash
git checkout -- templates/<name>/devenv.lock
```

A lock that does not pass its own tier must not ship. Then either fix the
template for the new inputs, or leave the pin where it is and note why.

Commit as `build(<name>): bump devenv.lock`, with the rationale in the
message — what moved and why now.

## Drift from a scheduled run

A weekly run going red with no commits in between is drift by definition, and
with nothing pinned every template is exposed to it — on either input. Triage
with the **test-template** skill's pinned-inputs check (`-o nixpkgs` first,
then `-o devenv` too when the modules are suspect), then fix the template. Do
not silence it by lowering a tier, and do not silence it by locking the
template — that hides the drift instead of fixing it.

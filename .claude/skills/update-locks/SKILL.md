---
description: >-
  Use when updating the committed flake.lock of a locked template
  (android-kotlin today), when deciding whether a template should become locked
  or unlocked, or when a scheduled CI run reports upstream nixpkgs drift.
---

# Updating a lock

One template ships a committed `flake.lock`: `android-kotlin` (CLAUDE.md §5).
Everything else resolves current nixpkgs on first use, so there is nothing to
update. Updating a lock is **consumer-facing** — whoever
runs `nix flake init -t` next gets exactly what the update resolved. It is not
housekeeping.

Bare `nix flake update` is hook-blocked because it moves every pin at once.

## Procedure

One template at a time, one commit each.

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

## Locking an unlocked template

Set `locked = true` in `meta/templates.nix`, add `!/<name>/flake.lock` to
`.gitignore`, generate the lock with `nix flake lock` in the template directory,
and commit. The `lock-policy` check enforces that the flag and the tracked file
agree, so the two must move together.

The bar for locking is resolution being slow or fragile — not "it broke once".
An unlocked template that breaks on drift is usually telling you the template
needs fixing.

## Unlocking

Reverse: `locked = false`, drop the negation line, `git rm --cached
<name>/flake.lock`. The consumer now gets current nixpkgs, which means the
weekly scheduled CI run becomes the only thing standing between drift and a
broken template — make sure that job is green first.

## Drift from a scheduled run

A weekly run going red with no commits in between is drift by definition. It is
an unlocked template nearly every time — the locked three are pinned. Triage
with the **test-template** skill's pinned-nixpkgs check, then fix the template.
Do not silence it by lowering a tier.

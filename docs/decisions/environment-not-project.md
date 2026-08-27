# A template ships an environment, not a project

**Why:** the rule already existed, stated in passing inside an Android document —
`docs/decisions/android-cli.md`: "this repo owns the *environment*, Google owns
the *project*." `dotnet` defers to `dotnet new`, `android-kotlin` defers to
`android create`. It is written here as a rule because the next reader looking
for it will not think to open a document about the Android CLI.

A template may ship whatever it takes to *prove the environment works* — a
`src/index.ts` and a test to delete, a `CMakeLists.txt` the `build` tier
compiles. It may not ship an opinion about how to structure an application. The
line is not size, it is who can keep the thing current: nixpkgs and the
language's own toolchain move on a schedule this repo tracks; a framework's
idioms do not.

**Breaks:** `ts-node-rest-api` was removed for sitting on the wrong side of it,
and `nix flake init -t github:Marcus441/nix-templates#ts-node-rest-api` no longer
resolves — the second break for that path after `981972a` renamed it from
`node-rest-api`. Nothing replaces it; `ts-node` is the Node environment.

**The evidence, since it is the clearest case the repo has produced.** The
template added nothing at the layer this repo owns. Its flake differed from
`ts-node`'s in three lines — `description`, `npmDepsHash`, the devShell `name` —
and its registry entry was identical, same `tier = "build"` and the same
`node --version` / `npm --version` smoke commands, so the harness proved nothing
about it that it did not already prove about `ts-node`. What differed was
`express`, `dotenv`, a middleware layout, a `CustomError` class and a
`JsonWebTokenError` → 401 special-case. `android-cli.md` names what that invites:
the old Android template shipped AGP 8.11.1 while AGP 9 had been out seven
months, because "a template's version catalog ages against nothing at all." A
`build` tier is a weaker defence against this than it looks — it proves the code
compiles, not that the idioms are still ones you would write.

**The C++ ladder is not a counter-example.** `cpp-simple` → `cpp` → `cpp-prod` →
`cpp-prod-modern` differ in build system: a plain Makefile, CMake and Ninja
presets, a library/exe split with sanitizer and coverage profiles, then the
library as a C++23 module. That is toolchain, which is the thing this repo owns,
and each rung changes what the flake and the `build` tier actually do. A ladder
whose rungs differ only in dependencies and file layout is a different animal.

**Also: where services and full-stack templates go.** Not here, and the reasoning
is in `docs/decisions/devenv.md` — process-compose in a plain devShell first, a
separate `devenv-templates` repo if that proves too thin, "decide between them
when such a template actually exists, not before." Two things to add now that the
trigger has been *named* — a local postgres and redis, a C#/React stack — but not
built:

- **The harness cannot follow.** *(No longer true — `devenv test` supplies the
  up / health-wait / run / down this bullet asks for, and
  `docs/decisions/devenv-templates.md` records the decision that followed. The
  reasoning is kept because it is what the second kind had to answer, and
  because the rule above it — a template ships an environment, not a project —
  governs a devenv template exactly as it governs a flake one.)* `scripts/test-template.sh` has no service
  lifecycle and no place to grow one cheaply. Each `smoke` entry is a separate
  `nix develop --command`, so nothing survives between them and a `pg_ctl start`
  in one is gone by the next. The `build` tier is a sandbox with no network, so a
  `doCheck` cannot reach a database. There is no teardown — the loop just
  `rm -rf`s the work dir — so a stray daemon outlives the run and leaks on a CI
  runner. Proving such a template needs up / health-wait / run / down, which is
  the "second harness path" `devenv.md` declined to build ahead of a real need.
- **So the second repo is a project, not a directory move.** Its cost is a
  harness, not a `git mv`. That is an argument for keeping it separate — a
  consumer opts into the toolchain by choosing the repo — and an argument against
  starting it before a template demands it.

**Rejected: keeping `ts-node-rest-api` behind a CLAUDE.md §7 divergence.** §7 is a
ratchet for debt being paid down, and it obliges a future reader to migrate the
item when they touch it. There was no migration available: with a three-line Nix
delta there is nothing left to extract or fix, so the entry would have been a
permanent licence rather than a debt.

**Rejected: reworking it to earn its place.** Stripping the application
architecture leaves `ts-node` with a different name, and the alternative —
raising what the harness proves about it — has nothing to prove that `ts-node`
does not already cover.

**Rejected: moving it to the second repo.** It needs no services and no second
runtime, so it would be as unjustified under that repo's thesis as under this
one. Relocating a template does not answer the question of whether it should
exist.

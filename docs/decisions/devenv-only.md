# Every template is a devenv environment

**The decision:** the flake kind is retired. All fourteen templates are native
devenv — `devenv.nix` and `devenv.yaml`, no `flake.nix` — in this repository,
under their existing names. Ten of the eleven flake templates were ported in
place; the eleventh, `shell`, was retired rather than ported, and bare
`nix flake init` now copies the `devenv` stub.

**Why:** a judgment, recorded as one: devenv is the better abstraction for
what these templates actually are — local development environments, and the
CI/CD that proves them. Processes, `services.<db>.enable`, readiness probes
and `enterTest` are the working vocabulary of a dev environment, and the flake
shape had none of it: each smoke command was a separate `nix develop`, the
`build` sandbox had no network, and nothing could supervise a service.
`devenv-templates.md` established that for the templates that needed services;
the rest were flake-shaped mostly because they predated the second kind. Once
no new template here would be written as a flake, the two-kind machinery — the
`kind` and `unfree` registry options, the checks and the harness path that
branched on kind, two lock filenames, the two-column tier table in CLAUDE.md
§3 — existed only to carry both shapes, and every piece of it was surface a
reader had to hold. The ladder is single-path again: `eval` is `devenv info`,
`shell` adds `devenv shell --` for each smoke command, `build` adds
`devenv test`.

**In place, deliberately.** Same repository, no rename, no archive, no second
repo. The root flake stays because it *is* the distribution mechanism:
`flake.templates` is the publication surface, and
`nix flake init -t github:Marcus441/nix-templates#<name>` remains the entry
point — the init is a kind-blind directory copy and never cared what a
template contains. A second repository was already rejected in
`devenv-templates.md`, when it would have meant maintaining two harnesses so
that one enum could stay an enum of one; collapsing the enum is that argument
finishing.

**The escape hatch, and its shelf life.** The annotated tag `flake-templates`
marks the last state with the eleven flake templates. It is reachable forever
and supported never: those templates are unlocked, so even at a frozen ref
they resolve *current* nixos-unstable against code nothing tests any more —
they will drift and eventually rot, and no CI leg watches them. Point a
consumer there only with that caveat attached.

**Breaks:** `nix develop` on a stock Nix install no longer works for any
template. Every template needs devenv installed first
(`nix profile install nixpkgs#devenv`). `devenv.md` named this cost — "the
consumer pays for it" — and `devenv-templates.md` accepted it scoped to the
templates whose names said so. The scope is gone; it is the price of the whole
repository now, stated in every welcomeText at the one moment a consumer is
guaranteed to be looking.

The rest of the list, all knowing:

- **The hermetic proof is gone.** A flake `build` tier ran
  `nix build .#default` — sandboxed, no network, the template's own `doCheck`
  inside. `devenv test` starts the declared processes, runs `enterTest` and
  stops them; it is not sandboxed and has network. More evidence that the
  environment actually works, none that anything builds hermetically. The
  two-column table §3 carried for this asymmetry is resolved by deleting a
  column, not by closing the gap.
- **A `systems` claim is enforced by the CI matrix alone, repo-wide.**
  `flake-inputs` used to render the registry's list and grep each flake for
  it, so the artifact stated its own platform claim; a devenv artifact has
  nowhere to state one. What `devenv-templates.md` booked as the devenv kind's
  asymmetry is now simply the rule. The nixpkgs spelling survives at the
  artifact level — `devenv-inputs` greps every `devenv.yaml` for the exact pin
  lines (Inv. 5) — the systems line does not.
- **Generated projects lose `packages.*` and `nix fmt`.** A flake template
  handed the consumer a buildable package output and a formatter; a devenv
  environment defines a shell, processes and a test, nothing else. A consumer
  who wants `nix build` writes their own flake.
- **dotnet's NuGet lock generator is retired.** The flake exposed
  `fetch-deps`, which wrote `nix/deps.json` to feed `buildDotnetModule`'s
  hermetic fetch. With no sandboxed build there is nothing to feed, and the
  template ships no project to lock — `dotnet new` scaffolds it.
- **`cpp-prod` and `cpp-prod-modern` flattened to one toolchain.** The flakes
  carried parallel `clang` and `gcc` devShells and packages; the devenv
  environments are clang-only, with the gcc swap documented as an edit in each
  README. One environment, one definition — the same rule that forbids a
  template shipping both `devenv.nix` and `flake.nix`.
- **`shell` is retired and the default moved.** Bare `nix flake init` used to
  copy `shell`; it now copies the `devenv` stub, and
  `nix flake init -t github:Marcus441/nix-templates#shell` no longer resolves
  — the same class of break `environment-not-project.md` books for
  `ts-node-rest-api`. Porting it was declined because a devenv environment
  with no packages already exists: it is the `devenv` stub, and a second name
  for the empty environment is exactly what `description-unique` exists to
  catch.

**Also: the drift tripwire now carries the whole repo, and it has already
fired.** Everything ships unlocked (§5, unchanged), so with no artifact-level
pin anywhere the weekly scheduled run is the only thing between upstream drift
and a consumer finding it first. During this migration it demonstrated both
halves: `typst`'s `aarch64-darwin` leg went red mid-run on an upstream nixpkgs
advance with no commit in this repository, and was green on re-run. That is
the first live sighting of the failure mode §5 describes, and its "a devenv
template is the first real candidate for `locked = true`" clause — written
when devenv templates were four of fifteen — now describes every template in
the repo. The bar is unchanged; the population under it is not.

**Rejected: a new repository, a rename, or an archival split.** Every init
command in the wild resolves this repository's default branch by name, so a
rename breaks all of them at once — §9 calls that out for changes far smaller
than this one. An archived flake-templates mirror would look maintained while
rotting; the tag makes the same state reachable while saying plainly that it
is frozen. And the second repository was costed twice
(`environment-not-project.md`, `devenv-templates.md`) and lost both times; it
does not improve by being renamed "archive".

**Rejected: keeping the flake kind for the templates that never wanted
services.** That is the status quo, and its price was the machinery above plus
a permanent split in what every claim in this repo means — two `build` tiers,
two lock files, two conventions documents, two harness paths on bash 3.2. The
one thing the flake kind still bought, the hermetic build proof, proves a
package output that exists to be proven rather than to be used: a template
ships an environment, and the environment is what `devenv test` exercises.

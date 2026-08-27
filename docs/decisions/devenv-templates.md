# devenv templates, as a second kind in this registry

**Why:** `docs/decisions/devenv.md` did not close the door, it deferred —
"decide between them when such a template actually exists, not before" — and
`docs/decisions/environment-not-project.md` named the trigger outright: "Two
things to add now that the trigger has been *named* — a local postgres and
redis, a C#/React stack — but not built." A fullstack template wanting a
supervised postgres is that trigger arriving, so this is the deferred decision
being made rather than a closed one being re-litigated.

Two facts decided it, and neither was available when `devenv.md` was written.

**The harness objection is gone.** `environment-not-project.md` rejected a
services template because "Proving such a template needs up / health-wait / run
/ down", and the harness had none of it: each `smoke` entry is a separate
`nix develop --command` so nothing survives between them, the `build` sandbox
has no network, and there was no teardown. `devenv test` is exactly that
missing lifecycle — it builds the environment, starts the declared processes,
runs `enterTest`, and stops them. A process carrying a readiness probe is not
complete until it is ready, so the probes genuinely gate the test rather than
merely existing. The thing that could not be proven can now be proven.

**devenv's flake integration is useless for this, which settles the shape.**
`devenv.lib.mkShell` in a `flake.nix` needs `nix develop --no-pure-eval`, and
devenv's own documentation says "running tests with flakes doesn't support
starting processes, for that you need to use `devenv`". That shape would break
Inv. 4 and Inv. 5, cost an impure evaluation, and deliver none of the supervised
services it was reached for. So a devenv template is *native* devenv:
`devenv.nix` plus `devenv.yaml`, and **no `flake.nix` at all**.

**Breaks:** the repository's one-sentence description of itself. It is no longer
eleven standalone flakes; it is eleven of those and a second kind that a stock
Nix install cannot run. `devenv.md`'s central objection — "the consumer pays for
it" — is not answered, it is *accepted*, and scoped: it is paid only by someone
who inits a `kind = "devenv"` template, and the name of every such template says
so before they run anything.

Three smaller costs, all real:

- **`tier = "build"` now means two things.** For a flake it is `nix build
  .#default`, sandboxed with no network. For devenv it is `devenv test`, which
  is not sandboxed and does have network. Strictly more evidence about services,
  strictly less about hermeticity. CLAUDE.md §3 carries both columns rather than
  letting one word quietly cover both.
- **A devenv template's `systems` is unbacked by its artifact.** `flake-inputs`
  renders the `systems` line from the registry and greps the flake for it, so a
  flake states its platform claim in the thing the consumer copies. devenv has
  no `systems` concept, so for this kind the claim is enforced only by the CI
  matrix.
- **An unlocked devenv template floats on two inputs, and only one of them is
  visible.** `devenv.yaml` declares nixpkgs; devenv adds *itself* as a second
  input, and `devenv.lock` pins both. So an unlocked devenv template tracks
  `cachix/devenv` — which means its *service modules* move under it, not just
  its packages. This is a wider drift surface than any flake template has, and
  it is invisible in the artifact: nothing in `devenv.yaml` mentions the input
  that carries the modules.

  It bit immediately. `devenv-postgres` was written against a `cachix/devenv`
  revision whose `services/postgres.nix` set `processes.postgres.shutdown`
  while its own `processes.nix` did not declare it, so the template shipped
  with a shim declaring the missing option. The input re-resolved within a day
  to a revision that declares it, and the shim became a duplicate-declaration
  error — the template broke, in the working tree, with no commit on either
  side. The shim is gone and the episode is the argument for §5's `locked`
  flag finally having a candidate.

**Also: the machinery, and why it was not as much as feared.** `devenv.md`
priced first-class support at "a `kind` field; `flake-inputs`, `lock-policy` and
`template-hygiene` each branching on it; a second harness path...; and a second
lock format". That estimate was right, and the work landed in six commits. Two
things it did not anticipate:

- A template with no `flake.nix` is an **eval error**, not a failed check.
  `descriptionOf` read the file and three checks interpolated its path, and both
  throw. It takes `nix flake check` down for every template, not just the one at
  fault — while `nix flake show`, `nix flake init -t` and
  `nix build .#registry-json` all keep working, because none of them forces a
  check's derivation. So the failure is loud where it should be, but it is
  whole-repo rather than local, and the checks were made total before anything
  used them.
- The harness resolves devenv itself, via `nix build --inputs-from` once per
  run, rather than requiring it on `PATH` with a CI install step. That keeps Inv. 5's single
  nixpkgs spelling (a bare `nixpkgs#devenv` would take the runner's own flake
  registry), pins the version to the root lock, and keeps devenv's 394 MiB
  closure off the `static` job — `nix flake check` realises `devShells`, so
  putting it in the dev shell would have put it on every push.

**Unchanged: a template still ships an environment, not a project.**
`environment-not-project.md` governs this kind exactly as it governs the other.
`devenv-postgres` ships no application code, and the fullstack templates this
class exists for defer their front end to `npm create vite` for the same reason
`android-kotlin` defers to `android create` — a shipped React app is a version
catalog that ages against nothing.

**Rejected: a second `devenv-templates` repository.** `devenv.md` offered it as
the fallback and `environment-not-project.md` costed it honestly — "the second
repo is a project, not a directory move. Its cost is a harness, not a `git mv`."
That cost is the argument against it. The harness, the registry, the tier
ladder, the CI matrix and the drift job all already exist here and all extend to
a second kind by branching rather than by duplication. A second repository would
have meant maintaining two of each, forever, so that one word in a registry
entry could stay an enum of one.

**Rejected: process-compose in a plain devShell.** `devenv.md` called this "the
first thing to try", and it is the right instinct — it keeps one input and every
invariant intact. It fails on the half that matters: the harness still has no
lifecycle, so the tier would prove `process-compose --version` and nothing about
the services, which is the §3 failure mode the whole exercise was meant to
avoid. It also means hand-writing the postgres bootstrap that
`services.postgres.enable` provides, which is the work devenv was reached for.

**Still rejected, and not reopened by any of this: the hybrid `.envrc`.**
`devenv.md`'s reasoning stands untouched — two definitions of one environment
with nothing checking that they agree, and which one a developer gets depending
on their `PATH`. `template-hygiene` now enforces it: a `kind = "devenv"`
template that also ships a `flake.nix` fails, and so does the reverse.

**Still rejected: devenv inside a `kind = "flake"` template.** Inv. 4 is
unchanged for that kind and `flake-inputs` still greps all five frameworks. A
generated project should not inherit a framework it did not ask for; choosing a
devenv template *is* asking.

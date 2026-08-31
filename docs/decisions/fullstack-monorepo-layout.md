# Full-stack templates ship a reference monorepo

**The decision:** `dotnet-react-postgres` and `go-react-postgres` follow one
monorepo layout, and they ship it populated — a minimal reference
architecture, not an empty environment:

```
apps/api/                the backend; its language's own conventions inside
apps/web/                Vite + React + TypeScript, shipped, typed from the contracts
packages/contracts/      the single source of API types
scripts/                 setup.sh, generate-contracts.sh
docs/                    architecture.md, getting-started.md
infra/docker/            deployment-parity images, wired by docker-compose.yml
docker-compose.yml
package.json             npm-workspaces root (apps/web, packages/contracts)
```

Inside `apps/api` the language rules: .NET is `Api.sln` over
`src/{Api,Application,Domain,Infrastructure}` plus `tests/`; Go is `cmd/` +
`internal/` + `db/migrations/` with a `Makefile`. The web half and the
contracts package are deliberately near-identical between the two templates.

**Why:** a full-stack template's value is the seams, and a scaffolder cannot
generate a seam. `npm create vite` produces a React app; it cannot produce a
React app whose types are imported from `@app/contracts`, whose dev server sits
behind the proxy `devenv up` supervises, and whose one test exercises the
shared contract. Handing the consumer an empty `apps/` and a README describing
the wiring would make the template's whole subject the one thing it does not
demonstrate. So the architecture is shipped, and kept minimal on purpose: one
resource, one page, one test per half — enough for `devenv test` to prove the
round trip and no more.

**devenv owns the dev loop; Docker is deployment parity only.** `devenv up`
owns postgres, the API and the Vite dev server, and `devenv test` proves them.
`docker-compose.yml` and `infra/docker/` exist so the published images can be
run the way a deployment would run them — nginx serving the built SPA,
proxying to the API — to answer "does the artifact run", never "how do I
develop". This is `devenv.md`'s anti-hybrid argument applied to compose: a
compose file that also ran development would be a second definition of one
environment, with nothing checking that the two agree and with which one a
developer gets decided by habit. One definition of local dev; the second
artifact answers a different question.

**Contracts: one invariant, two directions.** The invariant is that
`packages/contracts` is the single source of API types, and the TypeScript in
`src/api.d.ts` is derived and committed — the frontend typechecks offline, an
API change is a reviewable diff, and nobody edits generated types or
duplicates one into `apps/web`. Which artifact is authoritative follows the
language. .NET serves an OpenAPI document from the code, so the types are
generated from the running API — `scripts/generate-contracts.sh` starts one if
nothing answers — and the flow is code-first. Go's stdlib serves no such
document, and one resource does not justify the framework or annotation
generator that would, so `packages/contracts/openapi.yaml` is the committed
source of truth and the generator reads the file — spec-first, with the
handlers held to the spec by review and by `devenv test`'s round trip. Forcing
either language into the other's direction means fighting the toolchain the
template exists to hand over, so the adaptation is per-template and each
README says which way its arrow points.

**No `global.json`.** Nix pins the SDK — `devenv.nix` names it — so a second
pin would only be a second thing to keep in step, and the one that drifted
would win an argument silently.

**No npm lockfile.** Templates ship unlocked by policy (§5): the first
`npm install` resolves current versions, `setup.sh` reminds the consumer to
commit the lockfile it writes, and they are locked from then on. A committed
`package-lock.json` here would be a version catalog aging against nothing —
`android-cli.md`'s AGP lesson in npm form — and the manifests float (`^` and
`*` ranges) for the same reason.

**Breaks:** `docs/decisions/environment-not-project.md`, for these two
templates only. They ship exactly what it forbids — an opinion about how to
structure an application — and its aging argument is not answered, it is
accepted: `devenv test` proves the reference architecture compiles, comes up
and round-trips, not that its idioms are still the ones you would write. The
supersession is scoped. Every other template, devenv ones included, is still
bound, and no check can tell a reference architecture from a project — that
line is now held by review, which is weaker than a rule with a lint behind it.

Two more costs, both real:

- **The scaffolder position is reversed.** `devenv-templates.md` recorded the
  opposite intent — "the fullstack templates this class exists for defer their
  front end to `npm create vite`". Shipping `apps/web` reverses that,
  knowingly, for the seam reasons above; the mitigation for the aging it
  invites is the floating ranges, the absent lockfile, and a web half kept to
  one page and one test.
- **The two templates duplicate the whole monorepo scaffold.** Inv. 1 forbids
  sharing it, so `apps/web`, `packages/contracts`, the payload workflows and
  the compose wiring exist twice, held in step by hand — the C++ ladder's
  divergence, wider. A fix to one sibling is worth applying to the other.

**Rejected: compose in the dev loop** — a `docker compose up` path in the
README's dev instructions, or an `.envrc` that offers it. Two definitions of
one environment; the same reasoning that rejected the hybrid `.envrc` in
`devenv.md`, and the reason the compose file's header says what it is for.

**Rejected: one contracts direction imposed on both templates.** Uniformity
here would mean either bolting an OpenAPI framework onto Go's stdlib or
demoting .NET's emitted document to a hand-maintained copy — each template
demonstrating a workflow its ecosystem would not choose. The shared invariant
is the committed, derived `api.d.ts`; the direction is the documented
per-language adaptation.

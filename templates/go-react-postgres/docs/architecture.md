# Architecture

## Layout

```
apps/api/                  Go backend — one module, stdlib net/http + pgx
  cmd/api/                 main: the -addr flag, routing, /health
  internal/items/          store (pgx), HTTP handlers, NormalizeName + its unit test
  db/migrations/           numbered SQL files; `make migrate` applies them with psql
  Makefile                 run / test / build / migrate
apps/web/                  React + TypeScript + Vite; imports types from @app/contracts
packages/contracts/        openapi.yaml — the committed spec — and TS types generated from it
scripts/                   setup.sh, generate-contracts.sh
infra/docker/              deployment-parity images; wired up by docker-compose.yml
```

The Go side is deliberately smaller than its `dotnet-react-postgres` sibling's
four-project solution: one module, one `internal/items` package holding the
store, the handlers and the pure `NormalizeName` helper. The unit test covers
the helper alone, which is what lets it run without a database — the same
property the sibling gets from a fake repository.

The API creates its table at startup with `CREATE TABLE IF NOT EXISTS` —
idempotent, and honest about being a starting point. `db/migrations/` holds
the same DDL as `0001_init.sql` and is the growth path, not a boot
dependency: schema work beyond the first table becomes numbered files there,
applied in order by `make -C apps/api migrate` (plain `psql`). Swap in a real
migration tool when the numbered files outgrow it.

## The contracts flow

Spec-first — the reverse of the `dotnet-react-postgres` sibling, where the
framework serves an OpenAPI document at runtime and the committed types are
generated *from the code*. Go's stdlib serves no such document, and the
machinery that would (annotation generators, a web framework) is more than one
resource justifies, so here the document itself is the committed source of
truth:

1. `packages/contracts/openapi.yaml` describes the API surface — edit it
   first.
2. `scripts/generate-contracts.sh` runs `openapi-typescript` over that file —
   nothing needs to be running — and writes `packages/contracts/src/api.d.ts`.
3. `apps/web` depends on `@app/contracts` through the npm workspace and
   derives its types from it: `type Item = components["schemas"]["Item"]`.
4. The Go handlers in `apps/api` are made to agree by hand — nothing generates
   Go from the spec here. Review and `devenv test`'s round-trip are what hold
   them to it.

`api.d.ts` is committed, so the frontend typechecks without regeneration, and
a change to the API surface shows up as a reviewable diff in the same commit.
Changing an endpoint means: edit the spec, rerun the script, change the
handlers, commit all three. The generator's output format can drift across
`openapi-typescript` versions — expect a cosmetic diff the first time you
regenerate with a newer one.

## devenv vs docker

Two artifacts, two jobs, deliberately not one:

- **devenv owns local development.** `devenv up` supervises postgres (unix
  socket, no port to collide), the API and the vite dev server, in dependency
  order with readiness probes. `devenv test` is the end-to-end proof. The vite
  proxy in `apps/web/vite.config.ts` forwards `/items` and `/health` to the
  API, so the app fetches relative URLs and no CORS configuration exists
  anywhere.
- **docker-compose.yml is deployment parity.** It runs the two
  `infra/docker` images against a postgres container the way a deployment
  would — nginx serving the built SPA and proxying the same API paths
  (`infra/docker/nginx.conf`, the dev proxy's counterpart). It is never part
  of the dev loop; it exists so "does the published artifact actually run" is
  answerable locally before it is answered in production.

The API bridges the two through the libpq environment variables, which pgx
reads exactly as `psql` would: under devenv `PGHOST` is a socket directory,
under compose it is the `postgres` hostname plus `PGUSER`/`PGPASSWORD`. Same
binary, no configuration file.

## CI

Three payload workflows ship with the template (they run in the repo you
generate, not in the template collection): `ci.yml` runs `devenv test` on
Linux and macOS on every change, and `backend.yml`/`frontend.yml` are
path-filtered fast lanes that build and test only the half a change touched,
inside the same devenv shell so toolchains cannot diverge from local ones.

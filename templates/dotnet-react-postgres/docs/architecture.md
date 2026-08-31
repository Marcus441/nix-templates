# Architecture

## Layout

```
apps/api/                  .NET backend — one solution, four projects + tests
  src/Domain/              Item record; no dependencies
  src/Application/         IItemService/ItemService and the IItemRepository port
  src/Infrastructure/      Npgsql implementation; connection from the PG* env vars
  src/Api/                 minimal-API host: DI wiring, /health, /items, OpenAPI
  tests/Api.Tests/         xunit against Application with a fake repository — no DB
apps/web/                  React + TypeScript + Vite; imports types from @app/contracts
packages/contracts/        generated TypeScript types for the API — the one shared artifact
scripts/                   setup.sh, generate-contracts.sh
infra/docker/              deployment-parity images; wired up by docker-compose.yml
```

Dependencies point inward: Api → Application → Domain, with Infrastructure
implementing Application's `IItemRepository` port. The test project needs only
Application and Domain, which is what lets it run without a database.

The API creates its table at startup with `CREATE TABLE IF NOT EXISTS` —
idempotent, and honest about being a starting point. Replace it with a real
migration story when you have more than one table.

## The contracts flow

The backend is the source of truth for the API surface; nothing is duplicated
by hand:

1. `src/Api` serves an OpenAPI document at `/openapi/v1.json`
   (`Microsoft.AspNetCore.OpenApi` — the endpoint response and request types
   are inferred from the handlers).
2. `scripts/generate-contracts.sh` fetches that document and runs
   `openapi-typescript`, writing `packages/contracts/src/api.d.ts`.
3. `apps/web` depends on `@app/contracts` through the npm workspace and derives
   its types from it: `type Item = components["schemas"]["Item"]`.

`api.d.ts` is committed, so the frontend typechecks without the backend
running, and a change to the API surface shows up as a reviewable diff in the
same commit. Changing an endpoint means: change the C# handler, rerun the
script, commit both. The generator's output format can drift across
`openapi-typescript` versions — expect a cosmetic diff the first time you
regenerate with a newer one.

## devenv vs docker

Two artifacts, two jobs, deliberately not one:

- **devenv owns local development.** `devenv up` supervises postgres (unix
  socket, no port to collide), the API and the vite dev server, in dependency
  order with readiness probes. `devenv test` is the end-to-end proof. The vite
  proxy in `apps/web/vite.config.ts` forwards `/items`, `/health` and
  `/openapi` to the API, so the app fetches relative URLs and no CORS
  configuration exists anywhere.
- **docker-compose.yml is deployment parity.** It runs the two
  `infra/docker` images against a postgres container the way a deployment
  would — nginx serving the built SPA and proxying the same API paths
  (`infra/docker/nginx.conf`, the dev proxy's counterpart). It is never part
  of the dev loop; it exists so "does the published artifact actually run" is
  answerable locally before it is answered in production.

The API bridges the two through the libpq environment variables: under devenv
`PGHOST` is a socket directory, under compose it is the `postgres` hostname
plus `PGUSER`/`PGPASSWORD`. Same binary, no configuration file.

## CI

Three payload workflows ship with the template (they run in the repo you
generate, not in the template collection): `ci.yml` runs `devenv test` on
Linux and macOS on every change, and `backend.yml`/`frontend.yml` are
path-filtered fast lanes that build and test only the half a change touched,
inside the same devenv shell so toolchains cannot diverge from local ones.

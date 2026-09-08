# Architecture

## Layout

```
apps/api/                  .NET backend — one solution, four projects + tests
  src/Domain/              Item record; no dependencies
  src/Application/         IItemService/ItemService and the IItemRepository port
  src/Infrastructure/      Microsoft.Data.SqlClient implementation + schema bootstrap
  src/Api/                 minimal-API host: DI wiring, /health, /items, OpenAPI
  tests/Api.Tests/         xunit against Application with a fake repository — no DB
apps/web/                  Angular; imports types from @app/contracts
packages/contracts/        generated TypeScript types for the API — the one shared artifact
scripts/                   setup.sh, generate-contracts.sh
infra/docker/              deployment-parity images; wired up by docker-compose.yml
```

Dependencies point inward: Api → Application → Domain, with Infrastructure
implementing Application's `IItemRepository` port. The test project needs only
Application and Domain, which is what lets it run without a database.

The API creates its **database and then its table** at startup, both
idempotently (`IF DB_ID(...) IS NULL`, `IF OBJECT_ID(...) IS NULL`). The
PostgreSQL templates in this collection get the database itself from
`services.postgres.initialDatabases`; there is no SQL Server service to do
that, so the API owns both steps. It is idempotent and honest about being a
starting point — replace it with a real migration story when you have more
than one table.

## The contracts flow

The backend is the source of truth for the API surface; nothing is duplicated
by hand:

1. `src/Api` serves an OpenAPI document at `/openapi/v1.json`
   (`Microsoft.AspNetCore.OpenApi` — the endpoint response and request types
   are inferred from the handlers).
2. `scripts/generate-contracts.sh` fetches that document and runs
   `openapi-typescript`, writing `packages/contracts/src/api.d.ts`.
3. `apps/web` depends on `@app/contracts` through the npm workspace and derives
   its types from it: `type Item = components['schemas']['Item']`, in
   `src/app/items.service.ts`.

`api.d.ts` is committed, so the frontend typechecks without the backend
running, and a change to the API surface shows up as a reviewable diff in the
same commit. Changing an endpoint means: change the C# handler, rerun the
script, commit both. The generator's output format can drift across
`openapi-typescript` versions — expect a cosmetic diff the first time you
regenerate with a newer one.

## devenv vs docker

This template runs a container in the dev loop, which none of its siblings
does, so the line between the two artifacts is worth stating precisely:

- **devenv owns local development.** `devenv up` supervises three processes in
  dependency order with readiness probes — `sqlserver`, then `api` once
  `sqlcmd` answers, then the Angular dev server once the API answers
  `/health`. `devenv test` is the end-to-end proof. The `sqlserver` process
  *is* a `docker run`, but devenv starts it, waits on it and stops it: the
  container is an implementation detail of one process, not a second way to
  run the stack. The dev-server proxy in `apps/web/proxy.conf.json` forwards
  `/items`, `/health` and `/openapi` to the API, so the app fetches relative
  URLs and no CORS configuration exists anywhere.
- **docker-compose.yml is deployment parity.** It runs the two `infra/docker`
  images against a SQL Server container the way a deployment would — nginx
  serving the built SPA and proxying the same API paths
  (`infra/docker/nginx.conf`, the dev proxy's counterpart). It is never part
  of the dev loop; it exists so "does the published artifact actually run" is
  answerable locally before it is answered in production. Reaching for
  `docker compose up` to get a database is the one thing it is not for —
  `devenv up` already has one.

The API bridges the two through a single environment variable,
`ConnectionStrings__Default`: devenv points it at `127.0.0.1,1433`, compose at
`mssql,1433`. Same binary, no configuration file. Neither side hard-codes the
SA password — devenv's copy is composed by `mssql-connection-string` from the
one generated on first start, and compose reads `MSSQL_SA_PASSWORD` from the
environment — so the variable is required and the API throws without it.

## CI

Three payload workflows ship with the template (they run in the repo you
generate, not in the template collection): `ci.yml` runs `devenv test`,
`backend.yml` and `frontend.yml` are path-filtered fast lanes that build and
test only the half a change touched, inside the same devenv shell so
toolchains cannot diverge from local ones.

`ci.yml` runs on Linux only, where this collection's PostgreSQL templates also
run on macOS. That is the container dependency showing through: the GitHub
macOS runners have no container runtime, and Microsoft publishes the SQL
Server image for `linux/amd64` only.

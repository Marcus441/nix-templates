# dotnet-react-postgres

devenv environment for a .NET + React + PostgreSQL monorepo. The environment
gives you the SDK, Node, a supervised database and both dev servers; the code
that ships — one `items` resource end to end — is the smallest thing that
proves the whole chain, and is meant to be replaced.

```bash
nix flake init -t 'github:Marcus441/nix-templates#dotnet-react-postgres'
./scripts/setup.sh         # git init + add, then npm install inside the env
devenv up                  # or: direnv allow, then devenv up
```

## Requirements

**devenv, installed** — https://devenv.sh. There is no `flake.nix` here, so
`nix develop` does not apply. `nix profile install nixpkgs#devenv` is enough.

## Layout

```
apps/api/                  .NET backend: Api.sln, Domain/Application/
                           Infrastructure/Api projects, xunit tests
apps/web/                  React + TypeScript + Vite, one page over /items
packages/contracts/        generated TS types for the API — committed
scripts/                   setup.sh, generate-contracts.sh
docs/                      architecture.md, getting-started.md
infra/docker/              deployment-parity images for docker-compose.yml
```

`docs/architecture.md` explains the shape; the notes below explain the
environment.

## What you get

- **.NET 10 SDK** and **roslyn-ls**, Microsoft's own C# language server, on
  every platform
- **Node and npm** from nixpkgs, TypeScript language server wired up, and
  `npm install` run for the workspaces on shell entry
- **PostgreSQL**, started and stopped by devenv, database `app` created on
  first start, unix socket only — no TCP port to collide with a server you
  already run
- **three processes** — postgres, then the API once postgres is ready, then
  the vite dev server once the API answers `/health`
- **an end-to-end test** — `devenv test` checks `/health` against the
  database, POSTs an item and reads it back

## Building

devenv owns the dev loop; docker never enters it.

```bash
devenv up                  # postgres → api (:5080) → vite; Ctrl-C stops all
devenv up -d               # or background it
devenv processes down
devenv test                # the build-shaped proof: services up, API exercised
```

The usual per-half commands work inside the shell too:

```bash
dotnet build apps/api/Api.sln && dotnet test apps/api/Api.sln
npm run typecheck --workspace apps/web
npm run test --workspace apps/web
npm run build --workspace apps/web
```

`docker-compose.yml` and `infra/docker/` are the **deployment-parity artifact
only**: `docker compose up --build` runs the published images the way a
deployment would (nginx serving the built SPA, proxying to the API). Use it to
answer "does the artifact run", never for development.

## Contracts

The C# endpoints are the single source of the API surface. `src/Api` serves an
OpenAPI document at `/openapi/v1.json`; `./scripts/generate-contracts.sh`
(inside the shell, with the environment up) turns it into
`packages/contracts/src/api.d.ts` via `openapi-typescript`; `apps/web` imports
its `Item` type from `@app/contracts`. The file is committed so the frontend
typechecks offline and API changes show up as reviewable diffs — never edit it
by hand, and never duplicate a type into `apps/web`.

## CI

Three payload workflows for the repository you generate: `ci.yml` runs
`devenv test` on Linux and macOS on every change; `backend.yml` and
`frontend.yml` are path-filtered fast lanes that build and test only the half
a change touched, inside the same devenv shell as local work.

## Notes

- **Why there is no `flake.nix`.** devenv's flake integration cannot start
  processes — its own documentation says so — and it needs
  `nix develop --no-pure-eval`. Supervised services are the entire reason to
  reach for devenv, so that shape pays every cost and delivers none of the
  benefit.
- **Why there is no `global.json`.** Nix pins the SDK — `devenv.nix` names
  `sdk_10_0`, so a second pin would only be a second thing to keep in step.
- **Why there is no `package-lock.json`.** The template ships unlocked by
  policy, so your first `npm install` resolves current versions — commit the
  lockfile it writes (setup.sh reminds you) and you are locked from then on.
- **PostgreSQL is socket-only and its environment is already set.** devenv
  exports `PGHOST`, `PGPORT` and `PGDATA`; do not set them yourself. `PGHOST`
  is a socket *directory*, which is why `Infrastructure/Database.cs` passes it
  straight to Npgsql — a path-valued `Host` is how Npgsql spells "unix
  socket". The same `PG*` variables carry hostname and credentials under
  docker-compose. `psql -d app` works in the shell with no arguments.
- **Dependencies float on purpose.** `Npgsql` and `Microsoft.AspNetCore.OpenApi`
  use `*` patch ranges, the npm packages use `^` ranges. First restore/install
  takes current versions; the NuGet side has no committed lock, so pin exact
  versions the day floating stops being what you want.
- **`after` waits for readiness, not for start.** `api` declares
  `ready.http.get`, so `web` — and `enterTest` — wait until the API actually
  answers rather than until its process exists.
- **`devenv.lock` is not shipped; `devenv update` writes it and you commit it.**
  Write it early. `devenv.yaml` declares one input, but devenv adds *itself* as
  a second and the lock pins both — until then devenv's own service modules
  float, and the environment can change behaviour with no edit by you.
- **The .NET SDK is pinned to `sdk_10_0`** rather than tracking devenv's
  default, which is .NET 8, so that this template and the `dotnet` template
  agree on what current means. A pinned major eventually leaves nixpkgs, so
  treat it as something to bump rather than something to forget.
- **The C# language server is `roslyn-ls`, not devenv's default.** devenv
  defaults `languages.dotnet.lsp.package` to `csharp-ls`, which is a community
  project; `roslyn-ls` is the server behind Microsoft's own C# extension. The
  binary is `Microsoft.CodeAnalysis.LanguageServer` — point your editor at
  that, with `--stdio`.

  `lsp.enable` is set explicitly for a reason that is not obvious: its default
  is `availableOn <host> csharp-ls`, and `csharp-ls` declares
  `badPlatforms = ["aarch64-darwin"]`. So on an Apple Silicon Mac the default
  resolves to *false* and you get no C# server at all — and changing only
  `lsp.package` would not have fixed it, because the default is computed from
  `csharp-ls` whatever package you choose. `roslyn-ls` has no such exclusion.
- **The vite dev server proxies, the app fetches relative URLs.**
  `apps/web/vite.config.ts` forwards `/items`, `/health` and `/openapi` to
  `127.0.0.1:5080`, so there is no CORS configuration anywhere — and
  `infra/docker/nginx.conf` repeats the same routes for the composed
  deployment. Add new API prefixes in both places.
- **For editing `devenv.nix` itself, use `devenv lsp`.** It starts nixd
  already configured for this file, using the nixd bundled inside the devenv
  binary — so there is nothing to add to `packages`, and
  `devenv lsp --print-config` shows what it hands nixd.
- **There is no `nix fmt` here.** A flake template gets a `formatter` output;
  this one has no flake to hang it on. `dotnet format` covers the C# side,
  vite's defaults cover the rest, and devenv can run git hooks — see
  [devenv.sh/git-hooks](https://devenv.sh/git-hooks/).

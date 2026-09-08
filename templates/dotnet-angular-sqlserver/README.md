# dotnet-angular-sqlserver

devenv environment for a .NET + Angular + SQL Server monorepo. The environment
gives you the SDK, Node, a supervised database and both dev servers; the code
that ships — one `items` resource end to end — is the smallest thing that
proves the whole chain, and is meant to be replaced.

```bash
nix flake init -t 'github:Marcus441/nix-templates#dotnet-angular-sqlserver'
bash scripts/setup.sh      # git init + add, then npm install inside the env
devenv up                  # or: direnv allow, then devenv up
```

## Requirements

**devenv, installed** — https://devenv.sh. There is no `flake.nix` here, so
`nix develop` does not apply. `nix profile install nixpkgs#devenv` is enough.

**A container runtime**, which the other templates in this collection do not
need. SQL Server is not in nixpkgs, so `devenv up` runs Microsoft's image —
see the note below. `docker info` should succeed before you start.

**x86_64 Linux.** That is the only platform this template is tested on, and
the registry says so. The reasons are the same as the runtime requirement:
Microsoft publishes the SQL Server image for `linux/amd64` only, and CI's
macOS runner has no container runtime. It will very likely work on Apple
Silicon under Docker Desktop's emulation, and on aarch64 Linux under qemu —
neither is claimed, neither is tested.

## Layout

```
apps/api/                  .NET backend: Api.sln, Domain/Application/
                           Infrastructure/Api projects, xunit tests
apps/web/                  Angular, one page over /items
packages/contracts/        generated TS types for the API — committed
scripts/                   setup.sh, generate-contracts.sh
docs/                      architecture.md, getting-started.md
infra/docker/              deployment-parity images for docker-compose.yml
```

`docs/architecture.md` explains the shape; the notes below explain the
environment.

## What you get

- **.NET 10 SDK** and **roslyn-ls**, Microsoft's own C# language server
- **Node and npm** from nixpkgs, TypeScript language server wired up, and
  `npm install` run for the workspaces on shell entry
- **`sqlcmd`** and the Docker CLI on `PATH`, plus **`mssql`**, a `sqlcmd`
  wrapper that already knows the host, port, user and password
- **SQL Server**, started and stopped by devenv, listening on `127.0.0.1:1433`,
  with the `app` database and the `items` table created by the API at startup
- **a generated SA password**, written to `.devenv/state/mssql/sa-password` on
  first start — nothing secret is committed, and nothing is hard-coded here
- **three processes** — sqlserver, then the API once `sqlcmd` answers, then the
  Angular dev server once the API answers `/health`
- **an end-to-end test** — `devenv test` checks `/health` against the
  database, POSTs an item and reads it back

## Building

devenv owns the dev loop; docker-compose never enters it.

```bash
devenv up                  # sql server → api (:5080) → ng serve (:4200)
devenv up -d               # or background it
devenv processes down
devenv test                # the build-shaped proof: services up, API exercised
```

The usual per-half commands work inside the shell too:

```bash
dotnet build apps/api/Api.sln && dotnet test apps/api/Api.sln
npm run test --workspace apps/web
npm run build --workspace apps/web
mssql -d "$MSSQL_DATABASE" -Q 'SELECT * FROM items'
```

`docker-compose.yml` and `infra/docker/` are the **deployment-parity artifact
only**: `docker compose up --build` runs the published images the way a
deployment would (nginx serving the built SPA, proxying to the API). Use it to
answer "does the artifact run", never for development — `devenv up` already
gives you a database.

## Contracts

The C# endpoints are the single source of the API surface. `src/Api` serves an
OpenAPI document at `/openapi/v1.json`; `bash scripts/generate-contracts.sh`
(inside the shell, with the environment up) turns it into
`packages/contracts/src/api.d.ts` via `openapi-typescript`; `apps/web` imports
its `Item` type from `@app/contracts` in `src/app/items.service.ts`. The file
is committed so the frontend typechecks offline and API changes show up as
reviewable diffs — never edit it by hand, and never duplicate a type into
`apps/web`.

## CI

Three payload workflows for the repository you generate: `ci.yml` runs
`devenv test`; `backend.yml` and `frontend.yml` are path-filtered fast lanes
that build and test only the half a change touched, inside the same devenv
shell as local work. `ci.yml` runs on Linux only — the container requirement
again, and the reason this template's `ci.yml` has no macOS leg where the
PostgreSQL templates' do.

## Notes

- **SQL Server runs in a container, and that is the one unusual thing here.**
  Nothing else in this collection needs software Nix does not provide.
  Microsoft ships no SQL Server engine that nixpkgs packages, and devenv has
  no `services.mssql` to match its `services.postgres`, so the environment
  declares the database itself: `processes.sqlserver` is a `docker run` of
  `mcr.microsoft.com/mssql/server`, with a `sqlcmd` readiness probe in front
  of it. devenv still owns the dev loop — it starts the container, waits for
  it, and stops it — but `devenv shell` succeeding no longer implies
  `devenv up` will work, because the daemon is the host's.

  Consequences worth knowing:

  - `MSSQL_RUNTIME` selects the client. It is `docker` by default; set it to
    `podman` in `devenv.local.nix` (gitignored) if that is what you run.
  - The image tag `2022-latest` is a *floating* tag. `devenv.lock` pins
    nixpkgs and devenv; it cannot pin a container image, so this is one input
    the lock does not cover. Pin a digest in `devenv.nix` if you need that.
  - Data lives in a named volume, `<project>-mssql-data`, not under
    `.devenv/`. The image runs as uid 10001 and cannot write a host-owned bind
    mount, so a volume is the only option that survives a restart. It is
    roughly 150 MB, and being outside the project it outlives `devenv gc`,
    `rm -rf .devenv` and even deleting the directory — nothing here will ever
    reclaim it for you. `docs/getting-started.md` has the reset command.
  - **Removal trigger:** if nixpkgs ever packages the engine, or devenv grows
    a `services.mssql`, delete `processes.sqlserver`, use the service, drop
    the `docker-client` package and widen `systems`. Everything else here
    stays as it is.

- **The scripts are run as `bash scripts/…`, not `./scripts/…`.** `nix flake
  init` does not preserve the executable bit, so a freshly initialised copy has
  them at mode 644. `chmod +x scripts/*.sh` once, and commit that, if you would
  rather type `./scripts/setup.sh`.
- **`openapi-typescript` is a devDependency of the workspace root,** not of
  `packages/contracts`, even though it is the contracts package that gets
  written. npm does not hoist a non-root workspace's devDependency to the root
  `node_modules/.bin`, so `scripts/generate-contracts.sh` — a root-level
  script — would not find it there. `packages/contracts` ships no
  dependencies at all: it is a `types`-only package.
- **There is no unix socket, unlike the PostgreSQL templates.** SQL Server
  speaks TCP only, so port 1433 on loopback is the only option and it *can*
  collide with a server you already run. `MSSQL_PORT` is the knob; change it
  in `devenv.nix` and the connection string follows, because both are built
  from the same binding.
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
- **The SA password is generated, never shipped.** SQL Server refuses to start
  without one, and a password written into a template is a password every
  consumer of that template shares — so `mssql-password` writes a random one to
  `.devenv/state/mssql/sa-password` (mode 600, gitignored) the first time it is
  needed and prints it thereafter. Nothing in this template contains a
  credential. To use your own, write it into that file before the first start —
  the script only generates one when the file is missing. `rm -rf .devenv`
  discards the password, and the data volume then has to go too, since the two
  have to agree.
- **Nothing exports a connection string into your shell,** which is the cost of
  the point above. `mssql-connection-string` composes one from `MSSQL_PORT`,
  `MSSQL_DATABASE` and the generated password, and it is the single place that
  shape is written down: `processes.api` exports it, and
  `scripts/generate-contracts.sh` does the same for the API it may have to
  start. To run the API by hand, do what those do:

  ```bash
  ConnectionStrings__Default="$(mssql-connection-string)" \
    dotnet run --project apps/api/src/Api --urls http://127.0.0.1:5080
  ```

  `Database.cs` has no fallback and throws if the variable is unset, rather than
  reaching for a constant that would be a credential in the artifact.
- **`docker-compose.yml` reads `MSSQL_SA_PASSWORD` from your environment** and
  refuses to start without it, for the same reason. Inside the devenv shell,
  `export MSSQL_SA_PASSWORD="$(mssql-password)"` first. A real deployment
  supplies it from a secret store instead.
- **Dependencies float on purpose.** `Microsoft.Data.SqlClient` uses a `*`
  patch range, the npm packages use `^` and `~` ranges. First
  restore/install takes current versions; the NuGet side has no committed
  lock, so pin exact versions the day floating stops being what you want.
- **`after` waits for readiness, not for start.** `sqlserver` declares
  `ready.exec` and `api` declares `ready.http.get`, so each process waits until
  the one before it actually answers. The probe's `failure_threshold` is large
  on purpose: the default gives up thirty seconds in, which is less than the
  image pull, let alone SQL Server's own startup.
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
  `badPlatforms = ["aarch64-darwin"]`. Changing only `lsp.package` would not
  fix that, because the default is computed from `csharp-ls` whatever package
  you choose.
- **The dev server proxies, the app fetches relative URLs.**
  `apps/web/proxy.conf.json` forwards `/items`, `/health` and `/openapi` to
  `127.0.0.1:5080`, so there is no CORS configuration anywhere — and
  `infra/docker/nginx.conf` repeats the same routes for the composed
  deployment. Add new API prefixes in both places.
- **`ng test` is the typecheck's other half, and `ng build` is the typecheck.**
  There is no `typecheck` script here, where the React templates in this
  collection have `tsc --noEmit`: `tsc` cannot check an Angular template, and
  `ng build` checks both it and the TypeScript. The unit test is vitest —
  Angular's own default runner since v20, through the
  `@angular/build:unit-test` builder — so no browser is needed in CI.
- **For editing `devenv.nix` itself, use `devenv lsp`.** It starts nixd
  already configured for this file, using the nixd bundled inside the devenv
  binary — so there is nothing to add to `packages`, and
  `devenv lsp --print-config` shows what it hands nixd.
- **There is no `nix fmt` here.** A flake template gets a `formatter` output;
  this one has no flake to hang it on. `dotnet format` covers the C# side,
  `ng` ships no formatter of its own — add prettier if you want one — and
  devenv can run git hooks, see
  [devenv.sh/git-hooks](https://devenv.sh/git-hooks/).

# go-react-postgres

devenv environment for a Go + React + PostgreSQL monorepo. The environment
gives you the Go toolchain, Node, a supervised database and both dev servers;
the code that ships — one `items` resource end to end — is the smallest thing
that proves the whole chain, and is meant to be replaced.

```bash
nix flake init -t 'github:Marcus441/nix-templates#go-react-postgres'
./scripts/setup.sh         # git init + add, then npm install inside the env
devenv up                  # or: direnv allow, then devenv up
```

## Requirements

**devenv, installed** — https://devenv.sh. There is no `flake.nix` here, so
`nix develop` does not apply. `nix profile install nixpkgs#devenv` is enough.

## Layout

```
apps/api/                  Go backend: cmd/api, internal/items, db/migrations, Makefile
apps/web/                  React + TypeScript + Vite, one page over /items
packages/contracts/        openapi.yaml, the committed source of truth, + generated TS types
scripts/                   setup.sh, generate-contracts.sh
docs/                      architecture.md, getting-started.md
infra/docker/              deployment-parity images for docker-compose.yml
```

`docs/architecture.md` explains the shape; the notes below explain the
environment.

## What you get

- **Go**, tracking nixpkgs' default — plus `gopls`, `delve`, `gotools`,
  `go-tools`, `gomodifytags`, `impl`, `gotests` and `iferr`, all rebuilt
  against the same Go so a `vscode-go` or `vim-go` setup agrees with the
  compiler
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

The usual per-half commands work inside the shell too — `apps/api/Makefile`
wraps the Go ones:

```bash
make -C apps/api test      # go test ./... — the pure helper, no database
make -C apps/api build     # go build -o bin/api ./cmd/api; bin/ is gitignored
make -C apps/api migrate   # psql -f each db/migrations/*.sql, in order
npm run typecheck --workspace apps/web
npm run test --workspace apps/web
npm run build --workspace apps/web
```

`docker-compose.yml` and `infra/docker/` are the **deployment-parity artifact
only**: `docker compose up --build` runs the published images the way a
deployment would (nginx serving the built SPA, proxying to the API). Use it to
answer "does the artifact run", never for development.

## Contracts

Spec-first, and the opposite direction from this collection's
`dotnet-react-postgres`: there the running API serves an OpenAPI document and
the committed types are generated from it; here
`packages/contracts/openapi.yaml` **is** the committed source of truth,
because Go's stdlib serves no OpenAPI document and one resource does not
justify the machinery that would. `./scripts/generate-contracts.sh` runs
`openapi-typescript` over the committed spec — nothing needs to be running —
and writes `packages/contracts/src/api.d.ts`; `apps/web` imports its `Item`
type from `@app/contracts`. Both files are committed, so the frontend
typechecks offline and an API change shows up as a reviewable diff — never
edit `api.d.ts` by hand, and never duplicate a type into `apps/web`. The Go
handlers are held to the spec by review and by `devenv test`'s round-trip,
since nothing generates Go from it.

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
- **Why there is no `package-lock.json`.** The template ships unlocked by
  policy, so your first `npm install` resolves current versions — commit the
  lockfile it writes (setup.sh reminds you) and you are locked from then on.
- **Migrations are a growth path, not a boot dependency.** The API runs
  `CREATE TABLE IF NOT EXISTS` at startup, so it boots against an empty
  database; `apps/api/db/migrations/0001_init.sql` holds the same DDL and is
  where schema work beyond the first table goes — numbered files, applied in
  order by `make -C apps/api migrate`, which is plain `psql` until you swap in
  a real migration tool.
- **PostgreSQL is socket-only and its environment is already set.** devenv
  exports `PGHOST`, `PGPORT` and `PGDATA`; do not set them yourself. `PGHOST`
  is a socket *directory*, and pgx reads the same libpq variables `psql` does —
  so `pgx.Connect(ctx, "dbname=app")` needs no host, and a path-valued host is
  how pgx spells "unix socket". The same `PG*` variables carry hostname and
  credentials under docker-compose. `psql -d app` works in the shell with no
  arguments.
- **`github.com/jackc/pgx/v5` is the one third-party Go dependency,** and
  `go.sum` pins it exactly; `go get -u ./... && go mod tidy` inside `apps/api`
  bumps it. The npm side floats with `^` ranges instead — first install takes
  current versions, and the lockfile you commit is what stops that.
- **`GOTOOLCHAIN` is `local`, set by devenv.** So the `go` directive in
  `apps/api/go.mod` is a ceiling as well as a floor: if it exceeds the Go that
  nixpkgs ships, the build fails outright rather than quietly downloading
  another toolchain. The directive here is not a choice — `go mod tidy` raised
  it to what pgx requires, and every dependency bump can raise it again.
  nixpkgs' Go is comfortably ahead of it today; if a bump ever overtakes
  nixpkgs, `languages.go.package` is where you pick a newer compiler.
- **`GOPATH` is `.devenv/state/go`,** which devenv sets and `.gitignore`
  already covers. The module cache therefore lives inside the environment and
  a fresh clone re-downloads it; `devenv gc` will take it.
- **`gopls` needs no configuration here,** unlike the C# server in this
  collection's `dotnet-react-postgres`. `languages.go.lsp.enable` defaults to
  a plain `true` and `gopls` has no excluded platforms, so every system the
  registry claims gets a server. `languages.go.lsp.package` is the override.
- **`after` waits for readiness, not for start.** `api` declares
  `ready.http.get`, so `web` — and `enterTest` — wait until the API actually
  answers rather than until its process exists.
- **`devenv.lock` is not shipped; `devenv update` writes it and you commit it.**
  Write it early. `devenv.yaml` declares one input, but devenv adds *itself* as
  a second and the lock pins both — until then devenv's own service modules
  float, and the environment can change behaviour with no edit by you.
- **The vite dev server proxies, the app fetches relative URLs.**
  `apps/web/vite.config.ts` forwards `/items` and `/health` to
  `127.0.0.1:5080`, so there is no CORS configuration anywhere — and
  `infra/docker/nginx.conf` repeats the same routes for the composed
  deployment. Add new API prefixes in both places.
- **For editing `devenv.nix` itself, use `devenv lsp`.** It starts nixd
  already configured for this file, using the nixd bundled inside the devenv
  binary — so there is nothing to add to `packages`, and
  `devenv lsp --print-config` shows what it hands nixd.
- **There is no `nix fmt` here.** A flake template gets a `formatter` output;
  this one has no flake to hang it on. `gofmt` and `go vet` cover the Go side,
  vite's defaults cover the rest, and devenv can run git hooks — see
  [devenv.sh/git-hooks](https://devenv.sh/git-hooks/).

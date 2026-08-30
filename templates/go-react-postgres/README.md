# go-react-postgres

devenv environment for Go and React with a local PostgreSQL. The environment
gives you the Go toolchain, Node and a supervised database; you scaffold the
React front end yourself with `npm create vite` after entering it.

```bash
nix flake init -t 'github:Marcus441/nix-templates#go-react-postgres'
git init && git add -A
devenv shell               # or: direnv allow
```

## Requirements

**devenv, installed** — https://devenv.sh. There is no `flake.nix` here, so
`nix develop` does not apply. `nix profile install nixpkgs#devenv` is enough.

## What you get

- **Go**, tracking nixpkgs' default — plus `gopls`, `delve`, `gotools`,
  `go-tools`, `gomodifytags`, `impl`, `gotests` and `iferr`, all rebuilt
  against the same Go so a `vscode-go` or `vim-go` setup agrees with the
  compiler
- **Node and npm** from nixpkgs, with the TypeScript language server wired up
  (`languages.javascript.package` is the knob if you need a specific major)
- **PostgreSQL**, started and stopped by devenv rather than by you, with a
  database `app` created on first start and no TCP port to collide with a
  server you already run
- **two processes** — `api` waits for postgres to be *ready*, and `web` waits
  for `api`
- **a `/health` endpoint that actually queries the database**, so `devenv test`
  proves the whole chain rather than proving `go` is on `PATH`

What you do *not* get is a front end. `npm create vite` writes a better one than
this template could keep current — see step 1.

## Building

### 1. Scaffold the front end

```bash
npm create vite@latest web -- --template react-ts
npm --prefix web install
```

`web/` is where `languages.javascript.directory` and the `web` process already
point, so nothing in `devenv.nix` needs changing. Until this runs, the `web`
process prints that hint and exits — everything else works without it.

### 2. Run it

```bash
devenv up                  # postgres, then api, then web; Ctrl-C stops all
devenv up -d               # or background it
devenv processes down
```

The API comes up on <http://127.0.0.1:5080> and Vite on its own port. Point the
front end at the API with a `vite.config.ts` proxy, or set `VITE_API_URL`.

### 3. Compile a binary

```bash
go build -o bin/api ./cmd/api
```

`bin/` is gitignored. Build to a path rather than bare `go build ./cmd/api`,
which drops an `api` binary in the repository root.

### 4. Make it yours

Rename the module in `go.mod` — it ships as `app`, which is fine for a local
module and wrong the moment you publish one. Then delete `cmd/api/main.go`'s
`/health` endpoint once you have real ones, and replace `enterTest` in
`devenv.nix` with assertions about them.

## Testing

```bash
devenv test
```

Builds the environment, starts postgres and the API, waits for the API's
readiness probe, then asserts that `/health` returns `"db":1` — which it can
only do by connecting to PostgreSQL and running `SELECT 1`. Stops everything
afterwards, including on failure.

## CI

`.github/workflows/ci.yml` runs `devenv test` on Linux and macOS. One job,
where the flake templates in this collection need two: `devenv test` starts the
services, so it covers what a sandboxed `nix build` cannot.

## Notes

- **Why there is no `flake.nix`.** devenv's flake integration cannot start
  processes — its own documentation says so — and it needs
  `nix develop --no-pure-eval`. Supervised services are the entire reason to
  reach for devenv, so that shape pays every cost and delivers none of the
  benefit.
- **PostgreSQL is socket-only and its environment is already set.** devenv
  exports `PGHOST`, `PGPORT` and `PGDATA`; do not set them yourself. `PGHOST` is
  a socket *directory*, and pgx reads the same libpq variables `psql` does — so
  `pgx.Connect(ctx, "dbname=app")` needs no host, and a path-valued host is how
  pgx spells "unix socket". `psql -d app` works in the shell with no arguments.
- **`github.com/jackc/pgx/v5` is the one third-party dependency,** and `go.sum`
  pins it exactly. `go get -u ./... && go mod tidy` bumps it; nothing here
  floats, which is the opposite of what a version range would give you.
- **`GOTOOLCHAIN` is `local`, set by devenv.** So the `go` directive in `go.mod`
  is a ceiling as well as a floor: if it exceeds the Go that nixpkgs ships, the
  build fails outright rather than quietly downloading another toolchain. The
  directive here is not a choice — `go mod tidy` raised it to what pgx requires,
  and every dependency bump can raise it again. nixpkgs' Go is comfortably ahead
  of it today; if a bump ever overtakes nixpkgs, `languages.go.package` is where
  you pick a newer compiler.
- **`GOPATH` is `.devenv/state/go`,** which devenv sets and `.gitignore`
  already covers. The module cache therefore lives inside the environment and a
  fresh clone re-downloads it; `devenv gc` will take it.
- **`gopls` needs no configuration here,** unlike the C# server in this
  collection's `dotnet-react-postgres`. `languages.go.lsp.enable` defaults to a
  plain `true` and `gopls` has no excluded platforms, so every system the
  registry claims gets a server. `languages.go.lsp.package` is the override.
- **`processes.web` exits 0 rather than failing when `web/` is missing.**
  `devenv test` only treats a process as failed when it exits *non*-zero, so the
  template is green before you scaffold and stays green after. That is why the
  hint is an `echo` and not an error.
- **`after` waits for readiness, not for start.** `api` declares
  `ready.http.get`, so `web` — and `enterTest` — wait until the API actually
  answers rather than until its process exists.
- **`devenv.lock` is not shipped; `devenv update` writes it and you commit it.**
  Write it early. `devenv.yaml` declares one input, but devenv adds *itself* as
  a second and the lock pins both — until then devenv's own service modules
  float, and the environment can change behaviour with no edit by you.
- **For editing `devenv.nix` itself, use `devenv lsp`.** It starts nixd already
  configured for this file, using the nixd bundled inside the devenv binary —
  so there is nothing to add to `packages`, and `devenv lsp --print-config`
  shows what it hands nixd.
- **There is no `nix fmt` here.** A flake template gets a `formatter` output;
  this one has no flake to hang it on. `gofmt` and `go vet` cover the Go side,
  and devenv can run git hooks — see
  [devenv.sh/git-hooks](https://devenv.sh/git-hooks/).

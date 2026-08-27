# dotnet-react-postgres

devenv environment for .NET and React with a local PostgreSQL. The environment
gives you the SDK, Node and a supervised database; you scaffold the React front
end yourself with `npm create vite` after entering it.

```bash
nix flake init -t 'github:Marcus441/nix-templates#dotnet-react-postgres'
git init && git add -A
devenv shell               # or: direnv allow
```

## Requirements

**devenv, installed** — https://devenv.sh. There is no `flake.nix` here, so
`nix develop` does not apply. `nix profile install nixpkgs#devenv` is enough.

## What you get

- **.NET 10 SDK**, pinned to match the `dotnet` template in this collection
- **Node and npm** from nixpkgs, with the TypeScript language server wired up
  (`languages.javascript.package` is the knob if you need a specific major)
- **PostgreSQL**, started and stopped by devenv rather than by you, with a
  database `app` created on first start and no TCP port to collide with a
  server you already run
- **two processes** — `api` waits for postgres to be *ready*, and `web` waits
  for `api`
- **a `/health` endpoint that actually queries the database**, so `devenv test`
  proves the whole chain rather than proving `dotnet` is on `PATH`

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

### 3. Make it yours

Delete `api/Program.cs`'s `/health` endpoint once you have real ones, and
replace `enterTest` in `devenv.nix` with assertions about them.

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
  a socket *directory*, which is why `Program.cs` passes it straight to Npgsql —
  a path-valued `Host` is how Npgsql spells "unix socket". `psql -d app` works
  in the shell with no arguments.
- **`Npgsql` is the one floating dependency here.** `api.csproj` asks for
  `9.0.*` rather than an exact version, so `dotnet restore` takes the current
  patch. Pin it the day that stops being what you want.
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
- **The .NET SDK is pinned to `sdk_10_0`** rather than tracking devenv's default,
  which is .NET 8, so that this template and the `dotnet` template agree on what
  current means. The two spell the same major differently — `sdk_10_0` here,
  `dotnetCorePackages.dotnet_10.sdk` there — because devenv wants an SDK
  derivation and `buildDotnetModule` wants the wrapper attribute. A pinned major
  eventually leaves nixpkgs, so treat it as something to bump rather than
  something to forget.
- **There is no `nix fmt` here.** A flake template gets a `formatter` output;
  this one has no flake to hang it on. `dotnet format` covers the C# side, and
  devenv can run git hooks — see [devenv.sh/git-hooks](https://devenv.sh/git-hooks/).

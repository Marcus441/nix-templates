# devenv-sqlserver

devenv environment with a local SQL Server service.

```bash
nix flake init -t 'github:Marcus441/nix-templates#devenv-sqlserver'
git init && git add -A
devenv shell               # or: direnv allow
```

## Requirements

**devenv, installed** — https://devenv.sh. This template ships no `flake.nix`,
so `nix develop` does not apply to it. `nix profile install nixpkgs#devenv` is
enough.

**A container runtime**, which no other template in this repository needs.
nixpkgs has no SQL Server engine and devenv has no `services.mssql`, so this
template declares the service itself and runs Microsoft's image —
`docs/decisions/sqlserver-in-a-container.md` has the reasoning. `docker info`
should succeed before `devenv up`.

**An x86_64 host, or Apple Silicon with Rosetta.** Microsoft publishes the
image for `linux/amd64` only — no current tag has an arm64 build, `2025-latest`
included. `x86_64-linux` is what the registry claims, because it is what CI can
prove: the macOS runners have no container runtime at all, so a wider claim
would be one nothing tests.

Apple Silicon works, but through **Rosetta and not QEMU**, and the difference
is not cosmetic. Under QEMU `sqlservr` aborts at startup with `Invalid mapping
of address … in reserved address space below 0x400000000000`: SQL Server's
SQLPAL layer reserves its own address space, and QEMU's user-mode emulation
does not reproduce the layout it needs. Rosetta does. With colima:

```bash
colima start --vm-type vz --vz-rosetta --mount-type virtiofs \
  --cpu 4 --memory 4 --disk 60
```

Docker Desktop's *Use Rosetta for x86_64/amd64 emulation* setting is the
equivalent. Give the VM at least 4 GB — SQL Server will not start in the 2 GB
a default colima VM gets. This path is reported working; CI cannot cover it,
so it is documented rather than claimed.

aarch64 Linux has no Rosetta, so it gets QEMU and the failure above.

## What you get

- **SQL Server 2022 Developer edition**, started and stopped by devenv rather
  than by you
- **a generated SA password**, written to `.devenv/state/mssql/sa-password` on
  first start — nothing secret is committed, and nothing is hard-coded here
- **`mssql`**, a `sqlcmd` wrapper that already knows the host, port, user and
  password, so you can type `mssql -Q 'select 1'`
- **`devenv test`**, which starts the service, proves it answers, and stops it

## Running the database

```bash
devenv up                  # foreground, Ctrl-C to stop
devenv up -d               # background
devenv processes down      # stop the background ones
mssql -Q 'select 1'        # the wrapper supplies -S, -U, -P and -C
```

Anything `sqlcmd` accepts, `mssql` accepts — it forwards its arguments. Use
plain `sqlcmd` when you want a different server or login:

```bash
sqlcmd -S "127.0.0.1,$MSSQL_PORT" -U sa -P "$(mssql-password)" -C -Q 'select 1'
```

## Building

There is nothing to build: this template ships an environment, not a project.
The build-shaped command is `devenv test`, which builds the environment, starts
the declared processes, runs `enterTest` and stops them again:

```bash
devenv test
```

`devenv build <attribute>` builds a single attribute of `devenv.nix` if you
need to inspect one.

## Testing

`devenv test` runs the `enterTest` block in `devenv.nix`. As shipped it waits
for the server to accept connections, then creates a table in `tempdb`,
inserts a row and reads it back — so a pass means the service genuinely
started, not merely that `sqlcmd` is on `PATH`. Replace it with your own
assertions.

## Notes

- **The SA password is generated, never shipped.** SQL Server refuses to start
  without one, so `mssql-password` writes a random one to
  `.devenv/state/mssql/sa-password` (mode 600, gitignored) the first time it is
  needed and prints it thereafter. Nothing in this template contains a
  credential, which is the point: a password committed to a template is a
  password every consumer shares. To use your own, write it into that file
  before the first start — the script only generates one when the file is
  missing. `rm -rf .devenv` discards the password, and the data volume then
  has to go too, since the two have to agree.
- **SQL Server runs in a container, and that is the unusual thing here.**
  nixpkgs packages the *clients* — `sqlcmd`, `freetds`, `msodbcsql18` — but
  not the engine, and devenv has no `services.mssql` to match its
  `services.postgres`. So `processes.sqlserver` is a `docker run` with a
  `sqlcmd` readiness probe in front of it. devenv still starts it, waits for
  it and stops it, exactly as it would a native service — but `devenv shell`
  succeeding no longer implies `devenv up` will work, because the daemon is
  the host's. `MSSQL_RUNTIME` selects the client and is `docker` by default;
  set it to `podman` in `devenv.local.nix` if that is what you run.

  **Removal trigger:** if nixpkgs packages the engine, or devenv grows a
  `services.mssql`, replace `processes.sqlserver` with the service, drop
  `docker-client` from `packages` and widen the platform claim. Nothing else
  here depends on the container.
- **The process kills its container from a trap, and that is not belt and
  braces.** `processes.<name>.shutdown.grace` is *ignored* by devenv 2.x's
  native process manager — `devenv processes down` returns after its built-in
  five seconds whatever you set, which is not enough for SQL Server to stop, so
  the `docker run` client is killed and the container is orphaned. The first
  version of this template did exactly that: `devenv test` passed green and
  left SQL Server running. Hence the `trap … EXIT HUP INT TERM` issuing
  `docker rm --force`, which returns in about half a second. Delete the trap,
  run `devenv up -d` then `devenv processes down`, and check `docker ps` — if
  it is clean, devenv has started honouring `grace` and the trap can go.
- **A port, not a socket, and this template cannot do better.** SQL Server
  speaks TCP only, so `127.0.0.1:1433` can collide with a server you already
  run — the one thing `devenv-postgres` avoids by using a unix socket.
  `MSSQL_PORT` is the knob; the wrapper and the probe both read it.
- **Data outlives the project.** The image runs as uid 10001 and cannot write a
  host-owned bind mount, so the data directory is a named docker volume,
  `<project>-mssql-data`, rather than something under `.devenv/`. It is roughly
  150 MB and nothing here reclaims it — not `devenv gc`, not `rm -rf .devenv`,
  not deleting the directory. `docker volume rm "$(basename "$PWD")-mssql-data"`
  is the reset.
- **The image tag floats and no lock can pin it.** `devenv.lock` pins nixpkgs
  and devenv; `2022-latest` is outside its reach entirely. Pin a digest in
  `MSSQL_IMAGE` if you need reproducibility.
- **`enterTest` drops its table before creating it, and that matters.**
  `devenv test` keeps state in `.devenv/test-state` on purpose, so the eval
  cache stays warm — and the docker volume is not per-run state at all, so a
  create-then-insert would fail the *second* time. `tempdb` is emptied on
  restart but the server is not restarted between runs, hence the drop.
  Anything you put in `enterTest` has to be re-runnable.
- **No database is created for you, unlike `devenv-postgres`.** That template
  gets `app` from `services.postgres.initialDatabases`, one line of a service
  module. Here there is no service and no such option, so creating one would
  cost a second process and a script to guess a name you are going to change
  anyway. You get the server; `mssql -Q 'create database app'` is the whole
  gap, and `enterTest` uses `tempdb` so it needs nothing created.
- **For editing `devenv.nix` itself, use `devenv lsp`.** It starts nixd already
  configured for this file, using the nixd bundled inside the devenv binary, so
  there is nothing to add to `packages`. `devenv lsp --print-config` shows what
  it hands nixd.
- **Why there is no `flake.nix`.** devenv's flake integration cannot start
  processes — its own documentation says so — and it needs
  `nix develop --no-pure-eval`. Since supervised services are the entire reason
  to reach for devenv, the flake-integrated shape would pay every cost and
  deliver none of the benefit. Native devenv it is.
- **Why there is no fallback to `use flake`.** A hybrid `.envrc` would ship two
  definitions of one environment with nothing checking that they agree, and
  which one you got would depend on your `PATH`.
- **nixpkgs is pinned to `nixos-unstable`, not `devenv-nixpkgs/rolling`.**
  devenv defaults to its own fork; this template follows the same nixpkgs as
  every other template here.
- **Unlocked means devenv's own modules float, not just nixpkgs.** `devenv.yaml`
  declares one input, but devenv adds itself as a second, and `devenv.lock`
  pins both. Until you write that lock, the process and readiness machinery
  this template depends on is whatever `cachix/devenv` looks like today — and
  the `shutdown.grace` behaviour noted above is exactly the kind of thing that
  moves. `devenv update` writes the lock; do that early.
- **`devenv.lock` is not shipped; `devenv update` writes one and you commit
  it.** A lock in the template would be a lock over somebody else's empty input
  set. Yours pins your project and nothing here moves it afterwards.

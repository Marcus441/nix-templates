# devenv-postgres

devenv environment with a local PostgreSQL service.

```bash
nix flake init -t 'github:Marcus441/nix-templates#devenv-postgres'
git init && git add -A
devenv shell               # or: direnv allow
```

## Requirements

**devenv, installed** — https://devenv.sh. This template ships no `flake.nix`,
so `nix develop` does not apply to it. Every other template in this repository
runs on a stock Nix install; this one does not, and that is the trade being
made for supervised services. `nix profile install nixpkgs#devenv` is enough.

## What you get

- **PostgreSQL** from nixpkgs, started and stopped by devenv rather than by you
- **a database `app`**, created on first start
- **a socket, not a port** — nothing to collide with a PostgreSQL you already
  run, and nothing listening on the network
- **`devenv test`**, which starts the service, proves it answers, and stops it

## Running the database

```bash
devenv up                  # foreground, Ctrl-C to stop
devenv up -d               # background
devenv processes down      # stop the background ones
psql -d app                # the shell already points PGHOST at the socket
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
for PostgreSQL to accept connections, then creates a table, inserts a row and
reads it back — so a pass means the service genuinely started, not merely that
`psql` is on `PATH`. Replace it with your own assertions.

## Notes

- **Why there is no `flake.nix`.** devenv's flake integration cannot start
  processes — its own documentation says so — and it needs
  `nix develop --no-pure-eval`. Since supervised services are the entire reason
  to reach for devenv, the flake-integrated shape would pay every cost and
  deliver none of the benefit. Native devenv it is.
- **Why there is no fallback to `use flake`.** A hybrid `.envrc` would ship two
  definitions of one environment with nothing checking that they agree, and
  which one you got would depend on your `PATH`.
- **`eval "$(devenv direnvrc)"` rather than `devenv init`'s `source_url`.**
  `devenv init` writes a `source_url` pinned to a hash of a file on GitHub,
  which rots. The subcommand prints the installed devenv's own copy: no
  network, no hash to age, and a clear failure if devenv is missing — which is
  the right answer for this template.
- **nixpkgs is pinned to `nixos-unstable`, not `devenv-nixpkgs/rolling`.**
  devenv defaults to its own fork; this template follows the same nixpkgs as
  every other template here. The shim above is not caused by that choice — it
  reproduces identically under devenv's own default nixpkgs.
- **Unlocked means devenv's own modules float, not just nixpkgs.** `devenv.yaml`
  declares one input, but devenv adds itself as a second, and `devenv.lock`
  pins both. Until you write that lock, `services.postgres` is whatever
  `cachix/devenv` looks like today — so this template can change behaviour
  with no edit to it and no edit upstream that you asked for. It happened
  during development: a `devenv test` that passed one day failed the next
  because the module set had moved. `devenv update` writes the lock and stops
  it; do that early rather than after it surprises you.
- **`devenv.lock` is not shipped; `devenv update` writes one and you commit
  it.** A lock in the template would be a lock over somebody else's empty input
  set. Yours pins your project and nothing here moves it afterwards.
- **`services.postgres.package` is the version knob.** This template tracks
  nixpkgs' default major rather than pinning one, so it does not freeze a
  version that eventually leaves nixpkgs.
- **State lives in `.devenv/state` and is gitignored** (`devenv test` uses
  `.devenv/test-state`, so testing never touches the database you develop
  against). `rm -rf .devenv` resets both completely. The socket itself lives
  outside the project, under a short per-project runtime directory —
  `/run/user/<uid>/devenv-<hash>/postgres/` — which is what keeps it clear of
  the 104-byte limit macOS puts on a unix socket path.
- **Set `services.postgres.listen_addresses` if you need TCP** — a container,
  or a GUI client that cannot use a socket. It is empty by default, which is
  what keeps this template from fighting a system PostgreSQL on 5432.

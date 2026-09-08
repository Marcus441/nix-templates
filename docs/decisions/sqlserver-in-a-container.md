# SQL Server is a container devenv supervises

**The decision:** `devenv-sqlserver` declares its database as
`processes.sqlserver`, a `docker run` of `mcr.microsoft.com/mssql/server` with a
`sqlcmd` readiness probe in front of it. devenv starts it, waits on it and stops
it, exactly as it would a native service. The registry entry is
`tier = "build"` with `systems = ["x86_64-linux"]`.

**Why there was no other option.** Two facts, both checked rather than assumed:

- **nixpkgs has no SQL Server engine.** It has the clients — `sqlcmd`
  (go-sqlcmd), `freetds`, `unixODBC`, `unixodbcDrivers.msodbcsql18` — on all
  three systems. It has never had the server, because Microsoft ships it as
  `.deb`/`.rpm` packages built against a specific FHS layout, not as anything a
  derivation could reasonably wrap.
- **devenv has no `services.mssql`.** Forty-four service modules under
  `src/modules/services/` — postgres, mysql, mongodb, cockroachdb,
  clickhouse — and no SQL Server, for the same reason.

So the choice was never "container or nixpkgs". It was "container, or no SQL
Server template at all".

**It ships an environment, not a project.** `devenv-postgres` is the model and
the sibling: six files, a service, an `enterTest` that proves the service
answers, and nothing else. `docs/decisions/environment-not-project.md` binds
this template exactly as it binds that one — the full-stack exception in
`fullstack-monorepo-layout.md` is scoped to two templates and is not extended
here. Anyone who wants SQL Server underneath an application starts from this
template and adds the application; that is the point of keeping it generic.

**The SA password is generated, never shipped.** SQL Server refuses to start
without one, and a password written into a template is a password every
consumer of that template shares — so `scripts.mssql-password` writes a random
one to `.devenv/state/mssql/sa-password` at mode 600 on first use, and prints
it thereafter. `MSSQL_SA_PASSWORD` in `devenv.local.nix` overrides it. Nothing
in the artifact contains a credential, and nothing exports one into the
environment. This is not a theoretical concern: the first version of this work
hard-coded a development password into `devenv.nix`, `docker-compose.yml` and a
C# fallback, and GitGuardian failed the pull request for it while all 41
template legs passed green. A committed dev credential is a real finding, not a
style note.

**Breaks:** the repository's implicit promise that Nix supplies everything a
template needs. Fourteen templates are self-contained; this one is not.
`devenv shell` succeeding no longer implies `devenv up` will work, because the
container daemon is the host's and nothing in the environment can provide it.
That is stated in the template's README and in CLAUDE.md §7 rather than left
for a consumer to discover at `devenv up`.

The rest of the cost, all of it real:

- **The platform claim narrows to `x86_64-linux`.** Microsoft publishes the
  image for `linux/amd64` only, and the CI matrix's `macos-latest` runner has
  no container runtime — so `tier = "build"` on all three systems would claim
  something CI cannot prove, which CLAUDE.md §3 forbids. Narrowing is the
  honest option, and it buys the highest tier: the `ubuntu-latest` leg really
  does start SQL Server and exercise it. Apple Silicon under Docker Desktop's
  emulation and aarch64 Linux under qemu will likely work; both are untested
  and neither is claimed.
- **The image tag is an input no lock can pin.** `devenv.lock` pins nixpkgs and
  devenv. It has nothing to say about `2022-latest`, which floats under the
  template the way §5 describes for unlocked inputs — with the difference that
  no lock exists that *could* cover it.
- **A port, not a socket.** `.claude/rules/template-devenv-conventions.md`
  prefers a unix socket precisely so a template cannot collide with a server
  the developer already runs, and `devenv-postgres` follows it. SQL Server
  speaks TCP only, so `127.0.0.1:1433` is the only option and the collision is
  real. `MSSQL_PORT` is the knob.
- **The database outlives the project.** The image runs as uid 10001 and cannot
  write a host-owned bind mount, so the data directory has to be a named docker
  volume rather than something under `.devenv/`. It is about 150 MB, it
  survives `devenv gc` and `rm -rf`, and every harness run leaves one behind
  because the harness instantiates into a uniquely named temporary directory.
- **The process needs its own cleanup trap.** `processes.<name>.shutdown.grace`
  is not honoured by devenv 2.x's native process manager: `devenv processes
  down` returns after the built-in five seconds regardless, which is not enough
  for SQL Server to shut down, so the `docker run` client is killed and the
  container is orphaned. This was observed, not predicted — the first harness
  run reported PASS and left a container running. The process therefore runs the
  container in the background under a `trap … EXIT HUP INT TERM` that issues
  `docker rm --force`, which returns in about half a second. **Removal
  trigger:** if a future devenv honours `shutdown.grace` here, delete the trap,
  run `devenv up -d` then `devenv processes down`, and confirm `docker ps` is
  clean.

**Rejected: a bring-your-own external instance.** Ship the clients, read a
connection string from the environment, and let the developer point it at a
SQL Server they already run. It is pure Nix and works on all three systems. It
also means the template supervises nothing, so `devenv up` starts no processes
and `enterTest` can prove nothing whatever — the tier would drop to `shell`,
which CLAUDE.md §3 describes as proving almost nothing. A template whose whole
subject is a service has to start the service.

**Rejected: shipping an application on top of it.** The first version of this
work was a full-stack `dotnet-angular-sqlserver` — a .NET solution, an Angular
workspace, a contracts package, compose files and payload workflows. It passed
the harness, and it was still the wrong change: `environment-not-project.md`
forbids exactly that, the full-stack supersession is scoped to the two
templates that already exist, and a consumer who wants SQL Server under a
different stack would have had to delete most of the template first. The
environment is the reusable part; the application was noise around it.

**Rejected: unpacking Microsoft's `.deb` under `buildFHSEnv`.** SQL Server does
not run on stock Linux the way a normal daemon does — it ships its own host
extension layer and expects a specific glibc and kernel surface. There is no
maintained nixpkgs derivation for it because people have tried. It would also
be Linux-only, so it would not even buy back the platform claim the container
costs.

**Superseded if either upstream moves.** If nixpkgs packages the engine, or
devenv grows a `services.mssql`, the fix is small: delete `processes.sqlserver`,
enable the service, drop `docker-client` from `packages`, and widen `systems`.
Nothing else in the template depends on the container.

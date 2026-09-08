# Getting started

Requires [devenv](https://devenv.sh) — `nix profile install nixpkgs#devenv` —
and, unlike the other templates in this collection, **a working container
runtime**: SQL Server is not in nixpkgs, so devenv runs Microsoft's image as a
supervised process. `docker info` should succeed before you start.

```bash
nix flake init -t 'github:Marcus441/nix-templates#dotnet-angular-sqlserver'
bash scripts/setup.sh      # git init + git add, then npm install inside the env
devenv up                  # sql server → api (:5080) → ng dev server (:4200)
```

The first `devenv up` pulls the SQL Server image — about 1.7 GB unpacked — and
then waits for SQL Server to finish starting, so give it a few minutes. Open
<http://localhost:4200>; the page lists items and adds one via the API. Then:

```bash
devenv test                # end-to-end: health check + POST + GET through curl
devenv update              # write devenv.lock; commit it with package-lock.json
```

When you change the API surface:

```bash
devenv up -d
bash scripts/generate-contracts.sh
git add packages/contracts && git commit
```

To start from an empty database, stop the processes and drop the volume:

```bash
devenv processes down
docker volume rm "$(basename "$PWD")-mssql-data"
```

Everything else — the layout, the contracts flow, what docker-compose.yml is
for (and is not for) — is in [architecture.md](architecture.md). The README
carries the environment notes.

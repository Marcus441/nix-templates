# Getting started

Requires [devenv](https://devenv.sh) — `nix profile install nixpkgs#devenv`.

```bash
nix flake init -t 'github:Marcus441/nix-templates#dotnet-react-postgres'
./scripts/setup.sh         # git init + git add, then npm install inside the env
devenv up                  # postgres → api (:5080) → vite dev server (:5173)
```

Open the vite URL it prints; the page lists items and adds one via the API.
Then:

```bash
devenv test                # end-to-end: health check + POST + GET through curl
devenv update              # write devenv.lock; commit it with package-lock.json
```

When you change the API surface:

```bash
devenv up -d
./scripts/generate-contracts.sh
git add packages/contracts && git commit
```

Everything else — the layout, the contracts flow, what docker-compose.yml is
for (and is not for) — is in [architecture.md](architecture.md). The README
carries the environment notes.

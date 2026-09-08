#!/usr/bin/env bash
# One-time setup after `nix flake init`. devenv only sees files git knows
# about once this is a repository, and the npm workspaces need one install
# at the root — both are cheap to forget, so this does them for you.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v "${MSSQL_RUNTIME:-docker}" >/dev/null 2>&1; then
  echo "warning: no ${MSSQL_RUNTIME:-docker} on PATH." >&2
  echo "SQL Server is not in nixpkgs, so devenv runs it as a container -" >&2
  echo "'devenv up' needs a working container runtime. See the README." >&2
fi

if [ ! -d .git ]; then
  git init
fi
git add -A

devenv shell -- npm install

cat <<'MSG'

setup done. next:

  devenv up      # sql server, api, ng dev server
  devenv test    # end-to-end smoke test
  devenv update  # write devenv.lock, then commit it

npm install wrote package-lock.json - commit it along with devenv.lock.
MSG

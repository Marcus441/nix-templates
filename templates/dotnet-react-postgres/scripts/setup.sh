#!/usr/bin/env bash
# One-time setup after `nix flake init`. devenv only sees files git knows
# about once this is a repository, and the npm workspaces need one install
# at the root — both are cheap to forget, so this does them for you.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -d .git ]; then
  git init
fi
git add -A

devenv shell -- npm install

cat <<'EOF'

setup done. next:

  devenv up      # postgres, api, vite dev server
  devenv test    # end-to-end smoke test
  devenv update  # write devenv.lock, then commit it

npm install wrote package-lock.json - commit it along with devenv.lock.
EOF

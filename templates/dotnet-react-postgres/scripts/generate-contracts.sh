#!/usr/bin/env bash
# Regenerates packages/contracts/src/api.d.ts from the running API's OpenAPI
# document, so the TypeScript types are derived from the C# endpoints rather
# than maintained by hand.
#
# Run it INSIDE the devenv shell (a direnv-loaded shell counts, or prefix with
# `devenv shell --`): it needs dotnet, npm and the workspace install. The API
# connects to PostgreSQL at startup, so have the environment up first —
# `devenv up -d` is the easy way. If nothing answers on :5080 the script
# starts a temporary `dotnet run`, which still needs the postgres process.
set -euo pipefail

cd "$(dirname "$0")/.."

url="http://127.0.0.1:5080/openapi/v1.json"
out="packages/contracts/src/api.d.ts"
tmp="$(mktemp -d)"
api_pid=""

cleanup() {
  if [ -n "$api_pid" ]; then
    kill "$api_pid" 2>/dev/null || true
    wait "$api_pid" 2>/dev/null || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT

if ! curl -sf -o "$tmp/openapi.json" "$url"; then
  echo "no API on :5080, starting one (postgres must be running)..." >&2
  dotnet run --project apps/api/src/Api --urls http://127.0.0.1:5080 &
  api_pid="$!"
  for _ in $(seq 1 120); do
    if curl -sf -o "$tmp/openapi.json" "$url"; then
      break
    fi
    sleep 1
  done
fi

if [ ! -s "$tmp/openapi.json" ]; then
  echo "could not fetch $url" >&2
  exit 1
fi

npx openapi-typescript "$tmp/openapi.json" -o "$out"
echo "wrote $out - review the diff and commit it"

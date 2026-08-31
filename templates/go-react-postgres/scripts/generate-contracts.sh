#!/usr/bin/env bash
# Regenerates packages/contracts/src/api.d.ts from the committed OpenAPI spec,
# so the TypeScript types are derived from packages/contracts/openapi.yaml
# rather than maintained by hand.
#
# Deliberately simpler than dotnet-react-postgres's version of this script:
# there the spec is a document served by the running API, so the script has to
# start one; here the spec is a committed file, so nothing needs to be up.
#
# Run it INSIDE the devenv shell (a direnv-loaded shell counts, or prefix with
# `devenv shell --`): it needs npm and the workspace install.
set -euo pipefail

cd "$(dirname "$0")/.."

npx openapi-typescript packages/contracts/openapi.yaml -o packages/contracts/src/api.d.ts
echo "wrote packages/contracts/src/api.d.ts - review the diff and commit it"

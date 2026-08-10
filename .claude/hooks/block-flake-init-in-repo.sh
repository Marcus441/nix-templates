#!/usr/bin/env bash
# PreToolUse(Bash): `nix flake init -t .#foo` run inside this repository copies
# a template's files over the repository root — including its flake.nix over
# ours. Destructive, and easy to reach for when testing a template by hand.
#
# scripts/test-template.sh does exactly this, in a temp directory, which is the
# only place it is safe.
set -uo pipefail

cmd=$(jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0

grep -Eq '(^|[|;&([:space:]])nix[[:space:]]+flake[[:space:]]+(init|new)' <<<"$cmd" || exit 0

repo="${CLAUDE_PROJECT_DIR:-}"
[ -n "$repo" ] || exit 0

# Only object when the command would run with the repo as its working
# directory. A `cd "$work" && nix flake init` inside the harness is fine.
grep -Eq '(^|[[:space:]])cd[[:space:]]' <<<"$cmd" && exit 0
case "$PWD/" in
"$repo"/*) ;;
*) exit 0 ;;
esac

echo "Blocked: 'nix flake init' here would copy a template over the repository" >&2
echo "root, including its flake.nix over ours. Use ./scripts/test-template.sh," >&2
echo "which instantiates into a temp directory, or cd somewhere else first." >&2
exit 2

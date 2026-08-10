#!/usr/bin/env bash
# PreToolUse(Bash): a bare `nix flake update` moves existing pins.
#
# Three templates ship a committed flake.lock (CLAUDE.md 5), so repinning one is
# a consumer-facing change: whoever runs `nix flake init -t` next gets whatever
# this command resolved. It must be deliberate and it must be its own commit.
#
# Allowed: updating a named input (`nix flake update nixpkgs`), and locking a
# newly added input (`nix flake lock`).
set -uo pipefail

cmd=$(jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0

grep -Eq '(^|[|;&([:space:]])nix[[:space:]]+flake[[:space:]]+update' <<<"$cmd" || exit 0

# `nix flake update <input>...` names what it moves — that is a deliberate act.
# Bare `nix flake update`, or one with only flags, moves everything.
if grep -Eq 'nix[[:space:]]+flake[[:space:]]+update[[:space:]]+[^-[:space:]]' <<<"$cmd"; then
  exit 0
fi

echo "Blocked: bare 'nix flake update' moves every pin, including the three" >&2
echo "consumer-facing template locks (CLAUDE.md 5). Name the input you mean" >&2
echo "('nix flake update nixpkgs'), or use 'nix flake lock' to lock a new input." >&2
exit 2

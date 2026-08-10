#!/usr/bin/env bash
# Instantiate each template into a throwaway directory and test it as far as its
# declared tier allows.
#
#   ./scripts/test-template.sh              every template, at its declared tier
#   ./scripts/test-template.sh rust cpp     only these
#   ./scripts/test-template.sh --list       print the registry as a table
#   ./scripts/test-template.sh --tier eval  cap every template at eval
#   ./scripts/test-template.sh --keep rust  leave the temp dir for debugging
#
# This is the ONLY thing that proves a template works. `nix flake check`
# validates this repository's flake and the shape of the templates output; it
# never evaluates a template's own flake.
#
# It has to be a script rather than a check because a build sandbox has no
# network and recursive-nix is not enabled, so a derivation cannot run
# `nix flake init` or `nix develop`. See .claude/rules/harness.md before moving
# any of this into meta/checks.nix.
#
# PASS means every step the tier covers succeeded. SKIP means nothing ran —
# it is not a pass, and the summary counts it separately. XFAIL is a template
# marked `broken` in the registry failing as expected; an XPASS is a *failure*,
# because a template that started working must lose the flag.

set -uo pipefail

REPO=$(git rev-parse --show-toplevel) || exit 2
SYSTEM=$(nix eval --impure --raw --expr 'builtins.currentSystem') || exit 2

keep=0
ceiling=""
selected=()

while [ $# -gt 0 ]; do
  case "$1" in
  --keep) keep=1 ;;
  --tier)
    ceiling=${2:-}
    shift
    ;;
  --list) list=1 ;;
  -h | --help)
    sed -n '2,25p' "$0" | sed 's/^# \?//'
    exit 0
    ;;
  -*)
    echo "unknown flag: $1" >&2
    exit 2
    ;;
  *) selected+=("$1") ;;
  esac
  shift
done

# Flakes see only tracked files. A template file written but not staged is
# invisible to `nix flake init -t`, and the error names a missing path rather
# than an unstaged one.
git -C "$REPO" add -A >/dev/null 2>&1 || true

registry=$(nix build --no-link --print-out-paths "$REPO#registry-json" 2>/dev/null) || {
  echo "error: could not evaluate the registry" >&2
  echo "  retry verbosely:  nix build $REPO#registry-json" >&2
  exit 2
}

# macOS runners have bash 3.2, so no `mapfile` and no `readarray`.
all=()
while IFS= read -r line; do
  all+=("$line")
done < <(jq -r 'keys[]' "$registry")

if [ ${#selected[@]} -eq 0 ]; then
  names=("${all[@]}")
else
  names=()
  for n in "${selected[@]}"; do
    if jq -e --arg n "$n" 'has($n)' "$registry" >/dev/null; then
      names+=("$n")
    else
      echo "error: '$n' is not in the registry. Known: ${all[*]}" >&2
      exit 2
    fi
  done
fi

field() { jq -r --arg n "$1" ".[\$n].$2" "$registry"; }

if [ -n "${list:-}" ]; then
  printf '%-16s %-6s %-7s %-7s %s\n' template tier locked unfree reason
  for n in "${names[@]}"; do
    printf '%-16s %-6s %-7s %-7s %s\n' \
      "$n" "$(field "$n" tier)" "$(field "$n" locked)" "$(field "$n" unfree)" \
      "$(field "$n" 'reason // ""')"
  done
  exit 0
fi

# eval < shell < build
rank() { case "$1" in eval) echo 0 ;; shell) echo 1 ;; build) echo 2 ;; *) echo 0 ;; esac }

# Enough to carry a nix build failure's actual error, short enough that eleven
# of them do not bury the summary. `--keep` prints the path to the whole thing.
LOG_TAIL=${LOG_TAIL:-40}

pass=0
fail=0
skip=0
xfail=0
kept=()

printf '%-16s %-6s %s\n' template tier result

for name in "${names[@]}"; do
  tier=$(field "$name" tier)
  if [ -n "$ceiling" ] && [ "$(rank "$tier")" -gt "$(rank "$ceiling")" ]; then
    tier=$ceiling
  fi

  if ! jq -e --arg n "$name" --arg s "$SYSTEM" \
    '.[$n].systems | index($s)' "$registry" >/dev/null; then
    printf '%-16s %-6s SKIP  (not built for %s)\n' "$name" "$tier" "$SYSTEM"
    skip=$((skip + 1))
    continue
  fi

  # `mktemp -t` means "prefix" on BSD and "template" on GNU, so `-t` with an
  # XXXXXX template produces tmpl-cpp-XXXXXX.Ab12Cd on macOS. Pass a full path
  # instead, which both agree on.
  work=$(mktemp -d "${TMPDIR:-/tmp}/tmpl-$name-XXXXXX")

  # Beside the work dir, never inside it: the template copy gets `git add -A`d
  # and its own flake would then see a stray file. Each step overwrites it, so
  # after a failure it holds the failing step's output — which is the only way
  # to learn anything from a CI runner you cannot cd into.
  log="$work.log"

  # dotnet writes ~/.dotnet, npm writes ~/.npm, gradle writes ~/.gradle. Without
  # a redirected HOME the harness mutates the developer's home directory and
  # stops being reproducible on a fresh CI runner.
  export HOME="$work/home"
  mkdir -p "$HOME"

  # No registry entry sets `unfree` today — every template that needs it sets
  # config.allowUnfree in its own flake — so this array is normally empty, and
  # bash before 4.4 treats "${empty[@]}" as an unbound variable under `set -u`.
  # Hence ${impure[@]+"${impure[@]}"} at each use; macOS runners are bash 3.2.
  impure=()
  if [ "$(field "$name" unfree)" = "true" ]; then
    export NIXPKGS_ALLOW_UNFREE=1
    impure=(--impure)
  fi

  step=""
  ok=1
  (
    cd "$work" || exit 1
    nix flake init -t "$REPO#$name" >"$log" 2>&1
  ) || {
    ok=0
    step="nix flake init -t $REPO#$name"
  }

  if [ $ok -eq 1 ]; then
    # The copy is a fresh directory, so its own flake cannot see the files that
    # were just written into it until they are tracked. Same trap, second time.
    git -C "$work" init -q >/dev/null 2>&1
    git -C "$work" add -A >/dev/null 2>&1

    if ! (cd "$work" && nix flake check --no-build ${impure[@]+"${impure[@]}"}) >"$log" 2>&1; then
      ok=0
      step="nix flake check --no-build"
    fi
  fi

  if [ $ok -eq 1 ] && [ "$(rank "$tier")" -ge 1 ]; then
    while read -r cmd; do
      [ -n "$cmd" ] || continue
      if ! (cd "$work" && nix develop ${impure[@]+"${impure[@]}"} --command bash -c "$cmd") >"$log" 2>&1; then
        ok=0
        step="nix develop --command $cmd"
        break
      fi
    done < <(jq -r --arg n "$name" '.[$n].smoke[]?' "$registry")
  fi

  if [ $ok -eq 1 ] && [ "$(rank "$tier")" -ge 2 ]; then
    if ! (cd "$work" && nix build --no-link ${impure[@]+"${impure[@]}"} '.#default') >"$log" 2>&1; then
      ok=0
      step="nix build .#default"
    fi
  fi

  broken=$(field "$name" broken)

  if [ $ok -eq 1 ] && [ "$broken" = "true" ]; then
    # A template that started working must lose the flag, or the registry is
    # carrying a divergence that no longer exists.
    printf '%-16s %-6s XPASS\n' "$name" "$tier"
    printf '  marked broken=true but passed — drop the flag in meta/templates.nix\n'
    fail=$((fail + 1))
  elif [ $ok -eq 1 ]; then
    printf '%-16s %-6s PASS\n' "$name" "$tier"
    pass=$((pass + 1))
  elif [ "$broken" = "true" ]; then
    printf '%-16s %-6s XFAIL (%s)\n' "$name" "$tier" "$(field "$name" 'reason // ""')"
    xfail=$((xfail + 1))
  else
    printf '%-16s %-6s FAIL\n' "$name" "$tier"
    printf '  reproduce:  cd %s && %s\n' "$work" "$step"
    if [ -s "$log" ]; then
      printf '  last %d lines of output:\n' "$LOG_TAIL"
      tail -n "$LOG_TAIL" "$log" | sed 's/^/  | /'
    fi
    fail=$((fail + 1))
  fi

  if [ $keep -eq 1 ]; then
    kept+=("$work")
    printf '  full log:   %s\n' "$log"
  else
    rm -rf "$work" "$log"
  fi
done

echo
echo "$pass passed, $fail failed, $skip skipped, $xfail expected-fail"
if [ $skip -gt 0 ] || [ $xfail -gt 0 ]; then
  echo "SKIP and XFAIL are not PASS — those templates are not proven."
fi

if [ ${#kept[@]} -gt 0 ]; then
  echo
  echo "kept:"
  printf '  %s\n' "${kept[@]}"
fi

# A SKIP is not a pass. Only a failure is an error.
[ $fail -eq 0 ]

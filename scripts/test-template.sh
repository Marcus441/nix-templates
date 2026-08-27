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
# What each tier runs depends on the template's `kind` (CLAUDE.md 1.4):
#
#   kind = "flake"    nix flake check --no-build / nix develop / nix build
#   kind = "devenv"   devenv info / devenv shell -- / devenv test
#
# The devenv path starts real processes, so it tears them down before deleting
# the work directory, and on an interrupt too.
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
    # To the first blank line, so the header can grow without a line number
    # here having to be kept in step with it.
    sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
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

# devenv is not on a CI runner's PATH: the workflow calls this script directly
# rather than through the dev shell, which is what keeps the documented entry
# point honest on bash 3.2. Resolving it from *this* repo's nixpkgs rather than
# the caller's flake registry keeps Inv. 5's single spelling — a bare
# `nixpkgs#devenv` would take whatever the runner's registry pins, which is a
# fourth nixpkgs entering through the back door — and pins the devenv version
# to the root flake.lock, so it moves when a maintainer moves it.
#
# It is not added to the dev shell or to harness.nix's runtimeInputs on
# purpose: `nix flake check` realises devShells, so that would put devenv's
# 394 MiB closure on the static job on every push, for a binary that only a
# devenv template ever invokes. A devenv already on PATH wins, so an
# interactive run pays nothing.
#
# Not named `devenv`, or `command -v devenv` below would find the function.
DEVENV_BIN=$(command -v devenv || true)
run_devenv() {
  if [ -n "$DEVENV_BIN" ]; then
    "$DEVENV_BIN" "$@"
  else
    nix run --inputs-from "$REPO" nixpkgs#devenv -- "$@"
  fi
}

# The flake path has nothing to clean up beyond a directory, so this script has
# never needed a trap. devenv starts processes, and an interrupt between `up`
# and `down` leaves them running with their only handle inside a directory the
# shell is about to forget.
current_work=""
current_kind=""
# shellcheck disable=SC2317  # reached via trap
on_exit() {
  if [ -n "$current_work" ] && [ "$current_kind" = "devenv" ]; then
    (cd "$current_work" && run_devenv processes down) >/dev/null 2>&1 || true
  fi
}
trap on_exit EXIT INT TERM

if [ -n "${list:-}" ]; then
  printf '%-24s %-7s %-6s %-7s %-7s %s\n' template kind tier locked unfree reason
  for n in "${names[@]}"; do
    printf '%-24s %-7s %-6s %-7s %-7s %s\n' \
      "$n" "$(field "$n" kind)" "$(field "$n" tier)" "$(field "$n" locked)" \
      "$(field "$n" unfree)" "$(field "$n" 'reason // ""')"
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

printf '%-24s %-6s %s\n' template tier result

for name in "${names[@]}"; do
  tier=$(field "$name" tier)
  if [ -n "$ceiling" ] && [ "$(rank "$tier")" -gt "$(rank "$ceiling")" ]; then
    tier=$ceiling
  fi

  kind=$(field "$name" kind)

  # An explicit refusal rather than a silent drop: the impure array below holds
  # a nix flag, and devenv spells it -i as a *global* option that has to precede
  # the subcommand. A devenv template that needs unfree says so in devenv.yaml.
  if [ "$kind" = "devenv" ] && [ "$(field "$name" unfree)" = "true" ]; then
    echo "error: 'unfree' is not wired for kind=devenv" >&2
    echo "  set allowUnfree in ${name}'s devenv.yaml instead" >&2
    exit 2
  fi

  if ! jq -e --arg n "$name" --arg s "$SYSTEM" \
    '.[$n].systems | index($s)' "$registry" >/dev/null; then
    printf '%-24s %-6s SKIP  (not built for %s)\n' "$name" "$tier" "$SYSTEM"
    skip=$((skip + 1))
    continue
  fi

  # `mktemp -t` means "prefix" on BSD and "template" on GNU, so `-t` with an
  # XXXXXX template produces tmpl-cpp-XXXXXX.Ab12Cd on macOS. Pass a full path
  # instead, which both agree on.
  work=$(mktemp -d "${TMPDIR:-/tmp}/tmpl-$name-XXXXXX")
  current_work="$work"
  current_kind="$kind"

  # Beside the work dir, never inside it: the template copy gets `git add -A`d
  # and its own flake would then see a stray file. Each step overwrites it, so
  # after a failure it holds the failing step's output — which is the only way
  # to learn anything from a CI runner you cannot cd into.
  log="$work.log"

  # dotnet writes ~/.dotnet, npm writes ~/.npm, gradle writes ~/.gradle. Without
  # a redirected HOME the harness mutates the developer's home directory and
  # stops being reproducible on a fresh CI runner.
  export HOME="$work/home"
  # nix falls back to $HOME/.cache only when XDG_CACHE_HOME is unset, and
  # devenv reads the XDG variables directly rather than deriving them from
  # HOME. Without these three the redirect above is conditional on the caller
  # having left them unset, which is not something the harness can assume.
  #
  # XDG_CONFIG_HOME is deliberately not redirected: nix reads
  # $XDG_CONFIG_HOME/nix/nix.conf, and a developer whose experimental-features
  # live there rather than in /etc/nix would lose them mid-run.
  export XDG_CACHE_HOME="$HOME/.cache"
  export XDG_DATA_HOME="$HOME/.local/share"
  export XDG_STATE_HOME="$HOME/.local/state"
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
    # devenv reads the working tree rather than the index, but its own inputs
    # are flake refs, so this stays shared.
    git -C "$work" init -q >/dev/null 2>&1
    git -C "$work" add -A >/dev/null 2>&1
  fi

  if [ "$kind" = "devenv" ]; then
    if [ $ok -eq 1 ]; then
      if ! (cd "$work" && run_devenv info) >"$log" 2>&1; then
        ok=0
        step="devenv info"
      fi
    fi

    if [ $ok -eq 1 ] && [ "$(rank "$tier")" -ge 1 ]; then
      while read -r cmd; do
        [ -n "$cmd" ] || continue
        # The `--` is load-bearing: -c is a *global* devenv option (--clean), so
        # `devenv shell bash -c "…"` would scrub the environment being tested.
        if ! (cd "$work" && run_devenv shell -- bash -c "$cmd") >"$log" 2>&1; then
          ok=0
          step="devenv shell -- bash -c \"$cmd\""
          break
        fi
      done < <(jq -r --arg n "$name" '.[$n].smoke[]?' "$registry")
    fi

    if [ $ok -eq 1 ] && [ "$(rank "$tier")" -ge 2 ]; then
      # Builds the environment, starts the declared processes, runs enterTest,
      # stops them. This is the devenv analogue of `nix build .#default` — the
      # rung where the template's own checks run — but it is not sandboxed and
      # it does have network. CLAUDE.md 3.
      if ! (cd "$work" && run_devenv test) >"$log" 2>&1; then
        ok=0
        step="devenv test"
      fi
    fi

    # Before the rm -rf below, not in the cleanup branch: `processes down` finds
    # the supervisor through $work/.devenv, so deleting the directory first
    # orphans a daemon with no handle left to stop it. `devenv test` stops what
    # it started, but a run that failed partway through may not have.
    (cd "$work" && run_devenv processes down) >/dev/null 2>&1 || true
  else
    if [ $ok -eq 1 ]; then
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
  fi

  broken=$(field "$name" broken)

  if [ $ok -eq 1 ] && [ "$broken" = "true" ]; then
    # A template that started working must lose the flag, or the registry is
    # carrying a divergence that no longer exists.
    printf '%-24s %-6s XPASS\n' "$name" "$tier"
    printf '  marked broken=true but passed — drop the flag in meta/templates.nix\n'
    fail=$((fail + 1))
  elif [ $ok -eq 1 ]; then
    printf '%-24s %-6s PASS\n' "$name" "$tier"
    pass=$((pass + 1))
  elif [ "$broken" = "true" ]; then
    printf '%-24s %-6s XFAIL (%s)\n' "$name" "$tier" "$(field "$name" 'reason // ""')"
    xfail=$((xfail + 1))
  else
    printf '%-24s %-6s FAIL\n' "$name" "$tier"
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

  # Teardown already ran above, including under --keep: the reproduce line is
  # `cd $work && devenv test`, which starts the processes again anyway, and a
  # --keep in CI would otherwise leak them.
  current_work=""
  current_kind=""
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

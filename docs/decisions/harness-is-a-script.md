# The harness is a script, not a check

**Why:** a `nix build` sandbox has no network and no daemon socket, and
`recursive-nix` is not among this machine's `experimental-features`
(`fetch-tree flakes nix-command`). A derivation therefore cannot run `nix flake
init`, `nix flake check`, `nix develop` or `nix build`. Everything that proves a
template actually works has to happen outside the sandbox, which means a script.

**Breaks:** `nix flake check` cannot answer "do the templates work". It
validates this flake and the *shape* of the `templates` output — nix does check
that each `path` exists and that no unsupported attribute is present — but it
never evaluates a template's own flake. Two layers, two commands, and the cheap
one does not imply the expensive one.

**Also:** the split is load-bearing enough to be worth a rule
(`.claude/rules/harness.md`), because "move the instantiation into a check so
`nix flake check` covers everything" is the obvious-looking refactor that cannot
work. If a proposed check only needs to *read* template sources or the registry,
it belongs in `meta/checks.nix` and should go there — that layer is seconds, not
minutes.

**The split survived a second template kind.** A `checks` derivation cannot
start a postgres any more than it can run `nix develop` — no network, no
daemon — so `kind = "devenv"` went into `scripts/test-template.sh` beside the
flake path rather than into `meta/checks.nix`. What went into `checks.nix` was
the part that only reads sources: which files a kind must ship, and the nixpkgs
spelling in `devenv.yaml`.

**Rejected: adding each template as a `path:` input** so the root flake
evaluates them. It answers a different question — it evaluates the template in
place, from this repo's tree, never the copy a consumer gets — and the parent
lock would pin every template's nixpkgs, so the scheduled drift run would test a
frozen world.

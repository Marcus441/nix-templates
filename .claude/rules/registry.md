---
paths: "meta/*"
---

# The registry

`meta/` is this repo's own flake — flake-parts, one lock, one nixpkgs. It exists
to describe and test the templates. It is **not** a template and its idioms do
not belong in one (CLAUDE.md Inv. 7).

## flake.templates is derived

`meta/registry.nix` declares the `templates` option and maps it into
`flake.templates`:

```nix
config.flake.templates = mapped // {default = mapped.${config.defaultTemplate};};
```

where `mapped` is `lib.mapAttrs` over `config.templates`, projecting each entry
down to `path`, `description` and a `welcomeText`, and `defaultTemplate`
defaults to `"devenv"` — the stub is what a bare `nix flake init` copies.

Never write `flake.templates` by hand — a template that exists only there gets
no checks and no harness coverage, which is the whole failure mode this layer
was built to prevent.

This is enforced by nix, not by taste. `nix flake check` rejects any attribute
in `templates.<name>` other than `path`, `description` and `welcomeText`:

```
error: template 'rust' has unsupported attribute 'tier'
```

So the registry *has* to be a separate option projected down. Watch the naming:
**`config.templates` is the registry, `config.flake.templates` is the output.**

`default` reads `mapped`, never `config.flake.templates.<name>` — reading the
attrset you are simultaneously defining is an infinite recursion.

`path` defaults to `../templates + "/${name}"`, so the directory name **is**
the template name. Set `path` explicitly only if that ever stops being true,
and prefer renaming the directory.

## Fields

| Field | Notes |
| --- | --- |
| `description` | Required. Shown by `nix flake show` and `nix flake init -t`. |
| `tier` | `eval` \| `shell` \| `build` — CLAUDE.md §3. |
| `smoke` | Commands run in the template's shell at tier ≥ `shell`, via `devenv shell --`. Cheap and specific: `cargo --version`, not `cargo build`. |
| `systems` | Defaults to the registry flake's `systems`. Narrow only with a `reason`. For every template this is the *only* place the claim lives — there is no artifact line to grep — so the CI matrix is the sole enforcement. |
| `locked` | Ships a committed `devenv.lock`. Must match `.gitignore` — CLAUDE.md §5. A `devenv.lock` covers *more* than the artifact suggests: devenv adds itself as a second input, so the lock pins the service modules too, and an unlocked template floats on them. |
| `broken` | Failure at this tier is expected and tracked. The harness reports XFAIL instead of FAIL, and reports **XPASS as a failure** if it starts working — so the flag cannot rot. |
| `reason` | Required when `tier != "build"` or `systems` is narrowed. Say *why it cannot be proven further*, not what the tier is. |
| `welcomeText` | Almost always leave unset. `standardWelcome` in `registry.nix` builds the post-init message from `description`, and one message across fourteen templates is the point. Set it only to say something that text cannot. |

`broken` and a narrowed `systems` say different things and must not be
substituted for each other. `systems = ["x86_64-linux"]` means *this template
does not apply here*; `broken = true` means *it applies and is defective*.
Collapsing the second into the first buys a green SKIP at the cost of the repo
no longer describing itself.

## Adding a check

Static only — see `.claude/rules/harness.md` for what that excludes.

**Never interpolate a template path unguarded.** `${root + "/${n}/devenv.yaml"}`
throws at *eval* when the file is absent, and so does `builtins.readFile` on
it — which takes `nix flake check` down for every template rather than just the
one at fault. Guard every source read with the `exists` helper in `checks.nix`,
so a half-added template fails its own check, not the whole run. `nix flake
show`, `nix flake init -t` and `nix build .#registry-json` are unaffected —
none of them forces a check derivation. Prefer a pure-eval assertion over a
`runCommand` when the fact is knowable from the registry (`reason-required` is
one); use `runCommand` over a `lib.fileset` when it needs to read template
sources, and scope the fileset so a README edit does not rebuild every check.

Note `nix flake check` already validates `templates.<name>` as template
definitions, so a dangling `path` is caught for free — do not reimplement it.
And it checks only the current system unless passed `--all-systems`.

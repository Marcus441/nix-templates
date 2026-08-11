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
config.flake.templates =
  lib.mapAttrs (_: t: {inherit (t) path description;}) config.templates
  // {default = config.flake.templates.shell;};
```

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

`default` is built by applying the projection to `config.templates.<name>`, not
by reading `config.flake.templates.<name>` — reading the attrset you are
simultaneously defining is an infinite recursion.

`path` defaults to `../. + "/${name}"`, so the directory name **is** the
template name. Set `path` explicitly only if that ever stops being true, and
prefer renaming the directory.

## Fields

| Field | Notes |
| --- | --- |
| `description` | Required. Shown by `nix flake show` and `nix flake init -t`. |
| `tier` | `eval` \| `shell` \| `build` — CLAUDE.md §3. |
| `smoke` | Commands run inside `nix develop` at tier ≥ `shell`. Cheap and specific: `cargo --version`, not `cargo build`. |
| `systems` | Defaults to the flake's `systems`. Narrow only with a `reason`. |
| `locked` | Ships a committed `flake.lock`. Must match `.gitignore` — CLAUDE.md §5. |
| `unfree` | The harness exports `NIXPKGS_ALLOW_UNFREE=1` and adds `--impure`. Not needed when the template sets `config.allowUnfree` in its own `import nixpkgs`, which every template that needs it now does — so no entry sets this today. Prefer fixing the template over setting the flag: `--impure` is a cost the consumer pays too. |
| `broken` | Failure at this tier is expected and tracked. The harness reports XFAIL instead of FAIL, and reports **XPASS as a failure** if it starts working — so the flag cannot rot. |
| `reason` | Required when `tier != "build"` or `systems` is narrowed. Say *why it cannot be proven further*, not what the tier is. |
| `welcomeText` | Almost always leave unset. `standardWelcome` in `registry.nix` builds the post-init message from `description`, and one message across twelve templates is the point. Set it only to say something that text cannot. |

`broken` and a narrowed `systems` say different things and must not be
substituted for each other. `systems = ["x86_64-linux"]` means *this template
does not apply here*; `broken = true` means *it applies and is defective*.
Collapsing the second into the first buys a green SKIP at the cost of the repo
no longer describing itself.

## Adding a check

Static only — see `.claude/rules/harness.md` for what that excludes. Prefer a
pure-eval assertion over a `runCommand` when the fact is knowable from the
registry (`reason-required` is one); use `runCommand` over a `lib.fileset` when
it needs to read template sources, and scope the fileset so a README edit does
not rebuild every check.

Note `nix flake check` already validates `templates.<name>` as template
definitions, so a dangling `path` is caught for free — do not reimplement it.
And it checks only the current system unless passed `--all-systems`.

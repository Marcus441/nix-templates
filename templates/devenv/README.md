# devenv

Minimal devenv environment to fill in — the registry's default, copied by
`nix flake init` with no `-t`.

```bash
nix flake init -t 'github:Marcus441/nix-templates#devenv'
git init && git add -A
devenv shell               # or: direnv allow
```

## Requirements

**devenv, installed** — https://devenv.sh. There is no `flake.nix` here, so
`nix develop` does not apply. `nix profile install nixpkgs#devenv` is enough.

## What you get

A `devenv.nix` with an empty package list, a `devenv.yaml` pinning nixpkgs, and
the boilerplate every template in this collection ships: `.editorconfig`,
`.envrc`, `.gitignore` and this file.

Reach for `devenv-postgres` instead if a local PostgreSQL is all you need, or
`dotnet-react-postgres` if you want a worked multi-language example.

## Filling it in

### Packages

```nix
{pkgs, ...}: {
  packages = [
    pkgs.ripgrep
    pkgs.jq
  ];
}
```

Search names with `nix search nixpkgs <term>` or on
[search.nixos.org](https://search.nixos.org/packages).

### A language

devenv wires up toolchains for you rather than making you assemble them:

```nix
languages.rust.enable = true;
languages.python.enable = true;
languages.javascript = {
  enable = true;
  npm.enable = true;
};
```

The full list is at [devenv.sh/languages](https://devenv.sh/languages/).

### A service

This is the reason to choose devenv over a plain dev shell. Services are
started and stopped for you:

```nix
services.postgres = {
  enable = true;
  initialDatabases = [{name = "app";}];
};
```

PostgreSQL listens on a unix socket by default, so it cannot collide with one
you already run, and `PGHOST`, `PGPORT` and `PGDATA` are exported into the
shell for you — do not set them by hand. `psql -d app` just works.
[devenv.sh/services](https://devenv.sh/services/) lists the rest.

### A process

Anything you would otherwise run in a spare terminal:

```nix
processes.api = {
  exec = "cargo run";
  after = ["devenv:processes:postgres"];
  ready.http.get = {
    port = 8080;
    path = "/health";
  };
};
```

`after` waits for the named process to be *ready*, not merely started, when it
has a readiness probe. Probes come in three forms — `ready.exec` runs a command,
`ready.http.get` polls an endpoint, and `ready.notify` is systemd-style.

`devenv up` runs everything in the foreground; `devenv up -d` backgrounds it and
`devenv processes down` stops it.

### A test

`enterTest` is what `devenv test` runs, and it is the only part of the
environment that CI can hold you to:

```nix
enterTest = ''
  wait_for_port 8080 120
  curl -sf localhost:8080/health | grep -q ok
'';
```

Make it prove the environment *works* rather than that a binary is installed —
`psql --version` proves nothing that entering the shell does not. Connect,
write, read back.

## Building

There is nothing to build: this template ships an environment, not a project.
The build-shaped command is `devenv test`, which builds the environment, starts
any processes you have declared, runs `enterTest`, and stops them again:

```bash
devenv test
```

`devenv build <attribute>` builds a single attribute of `devenv.nix` if you need
to inspect one.

## Notes

- **Why there is no `flake.nix`.** devenv's flake integration cannot start
  processes — its own documentation says so — and it needs
  `nix develop --no-pure-eval`. Supervised services are the whole reason to
  reach for devenv, so the flake-integrated shape pays every cost and delivers
  none of the benefit.
- **Do not add a `flake.nix` alongside this.** Two definitions of one
  environment, with nothing checking that they agree and which one you get
  depending on your `PATH`.
- **`devenv.lock` is not shipped; `devenv update` writes it and you commit it.**
  A lock in the template would be a lock over somebody else's empty input set.
- **Write the lock early.** `devenv.yaml` declares one input, but devenv adds
  *itself* as a second, and the lock pins both. Until you write it, devenv's own
  service modules float — so the environment can change behaviour with no edit
  by you and no release you asked for.
- **`.envrc` uses `eval "$(devenv direnvrc)"`** rather than the `source_url`
  line `devenv init` writes, which pins a hash of a file on GitHub and rots.
  This form asks your installed devenv for its own copy.
- **For editing `devenv.nix` itself, use `devenv lsp`.** It starts nixd already
  configured for this file, using the nixd bundled inside the devenv binary, so
  there is nothing to add to `packages`. `devenv lsp --print-config` shows what
  it hands nixd.
- **There is no `nix fmt` here.** A flake template gets a `formatter` output;
  this one has no flake to hang it on. `devenv` integrates git hooks if you want
  formatting enforced — see
  [devenv.sh/git-hooks](https://devenv.sh/git-hooks/).

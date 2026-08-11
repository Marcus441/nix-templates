# python

Dev environment for Python with uv, ruff and mypy.

```bash
nix flake init -t github:Marcus441/nix-templates#python
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
uv sync                    # creates .venv and writes uv.lock — commit the lock
```

## What you get

- **`python3`, `uv` and `ruff`** from nixpkgs, with `uv` wired to that exact
  interpreter — it never downloads a CPython of its own
- **mypy** in strict mode and **pytest** with a `src/` layout, both installed by
  `uv` so they can import your dependencies
- every tool configured in `pyproject.toml`, so your editor, `uv run` and CI all
  read one policy
- a `packages.default` built by `buildPythonApplication` and **hatchling**,
  running pytest in a sandbox with no network
- a **GitHub Actions workflow** that builds on Linux and macOS and runs ruff,
  mypy and pytest through the dev shell

## Layout

```
pyproject.toml        project metadata, dependencies and every tool's config
src/myproject/        the package — cli.py, __main__.py
tests/                pytest, importing the installed package
flake.nix             the dev shell and the packaged build
```

## Building

```bash
uv build                # wheel and sdist into dist/
```

Or build the Nix package, which builds in a sandbox and runs the tests:

```bash
nix build
nix run -- Ada          # runs the built binary
```

## Testing

```bash
uv run pytest
uv run mypy
ruff check .
ruff format .
```

Coverage is a separate command on purpose — see the notes below:

```bash
uv run pytest --cov=src/myproject --cov-report=term-missing
```

## Notes

- **Who owns what.** Nix owns the interpreter, `uv`, `ruff`, and the sandboxed
  release build; `uv` owns `.venv` and everything in it — every third-party
  package, plus `mypy` and `pytest`, which is why those two are in
  `[dependency-groups] dev` and not in `flake.nix`. `pyproject.toml` is the only
  file both read, and they read different parts: `uv` reads all of it, the flake
  reads `[project] name`, `[project] version` and `[project.scripts]` and
  nothing else — **nothing on the Nix side reads `uv.lock`**. So a runtime
  dependency is declared twice on purpose: `uv add httpx` for the dev loop, and
  `dependencies = [pkgs.python3Packages.httpx]` in `flake.nix` for `nix build`.
  The rule of thumb: if you typed it, it came out of `.venv`; if `nix build` ran
  it, it came out of nixpkgs.
- **Do not add a Python library to the flake's `packages`.** nixpkgs' Python
  setup hook appends every such package to `PYTHONPATH`, and `PYTHONPATH` is
  searched *before* a venv's own `site-packages` — so it would shadow whatever
  `uv` installed. This is why `ruff` is safe there and `mypy` would not be:
  `ruff` is a Rust binary that never touches `PYTHONPATH`, while nixpkgs' `mypy`
  is a Python package wrapped against the nixpkgs interpreter, so it could not
  import your dependencies anyway. Libraries belong in `pyproject.toml`.
- **`.envrc` puts `.venv/bin` on `PATH`**, so under direnv `pytest` and
  `uv run pytest` are the same pytest. Under a bare `nix develop` they are not:
  `.venv/bin` is not on `PATH`, so bare `pytest` is *command not found* rather
  than a different, silently wrong environment. `uv run <tool>` is the one
  spelling that works either way.
- **Rename the project in `pyproject.toml`, then rename `src/myproject/`.** The
  flake reads `[project] name`, `[project] version` and the key of
  `[project.scripts]` with `builtins.fromTOML`, so `pname`, `version` and
  `meta.mainProgram` — the thing that makes `nix run` work — all follow.
- **`uv.lock` is not shipped; `uv sync` writes it and you commit it.** Nothing
  on the Nix side reads it, so a lock shipped in the template would be a lock
  over somebody else's empty dependency set. The workflow runs
  `uv sync --locked`, which fails loudly if the committed lock is stale.
- **`LD_LIBRARY_PATH` is set on Linux** so pip-installed manylinux wheels can
  find `libstdc++` and `libz` on NixOS. It is inherited by every process you
  launch from this shell, including editors, so the list is kept to two entries
  — extend it for a specific wheel, or delete the block and take the package
  from `python3Packages` instead. Wheels that ship an *executable* need the
  dynamic loader and this does not help them.
- **After a nixpkgs bump moves `python3`**, `.venv` points at a store path that
  no longer exists: `rm -rf .venv && uv sync`.
- **`pytest-cov` is in `nativeCheckInputs` but `--cov` is not in `addopts`.**
  Coverage is an explicit command, so `nix build` can never fail on a coverage
  threshold; the plugin is present so that adding `--cov` to `addopts` later
  does not break the sandboxed build.
- **`buildPythonApplication` needs no `checkPhase`** — `pytestCheckHook` appends
  its own phase. Supplying one would replace `installCheckPhase` and silently
  disable the hook.
- `nix fmt` formats `flake.nix` with alejandra.

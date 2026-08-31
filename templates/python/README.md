# python

devenv environment for Python with uv, ruff and mypy.

```bash
nix flake init -t 'github:Marcus441/nix-templates#python'
git init && git add -A
devenv shell               # or: direnv allow
uv sync                    # creates .venv and writes uv.lock — commit the lock
```

## Requirements

**devenv, installed** — https://devenv.sh. There is no `flake.nix` here, so
`nix develop` does not apply. `nix profile install nixpkgs#devenv` is enough.

## What you get

- **`python3` and `uv`** from nixpkgs, wired to each other by devenv's Python
  module — `uv` never downloads a CPython of its own
- **`ruff`** from nixpkgs, via `packages` in `devenv.nix`
- **mypy** in strict mode and **pytest** with a `src/` layout, both installed by
  `uv` so they can import your dependencies
- every tool configured in `pyproject.toml`, so your editor, `uv run` and CI all
  read one policy
- **`devenv test`**, which builds the environment, then runs `uv sync` and the
  test suite
- a **GitHub Actions workflow** that runs `devenv test` on Linux and macOS,
  plus a lint job for ruff, mypy and pytest

## Layout

```
pyproject.toml        project metadata, dependencies and every tool's config
src/myproject/        the package — cli.py, __main__.py
tests/                pytest, importing the installed package
devenv.nix            the environment — interpreter, uv, ruff, enterTest
devenv.yaml           its one declared input, nixpkgs
```

## Building

```bash
uv sync                 # resolve and install into .venv
uv build                # wheel and sdist into dist/
uv run myproject Ada    # the CLI entry point, from .venv
```

The build-shaped command for the environment is `devenv test`: it builds the
environment, then runs `uv sync` and pytest. It is not sandboxed — `uv sync`
needs the network to reach PyPI.

```bash
devenv test
```

## Testing

```bash
uv run pytest
uv run mypy
ruff check .
ruff format .
```

Coverage stays a separate command:

```bash
uv run pytest --cov=src/myproject --cov-report=term-missing
```

## Notes

- **Who owns what.** devenv owns the interpreter, `uv` and `ruff`; `uv` owns
  `.venv` and everything in it — every third-party package, plus `mypy` and
  `pytest`, which is why those two are in `[dependency-groups] dev` and not in
  `devenv.nix`. Nothing in `devenv.nix` reads `pyproject.toml`, so
  `uv add httpx` is the whole move for a new dependency.
- **Do not add a Python library to `packages` in `devenv.nix`.** A nixpkgs
  Python package is wrapped against the nixpkgs interpreter, so it could not
  import what `uv` installed — nixpkgs' `mypy` would see none of your
  dependencies. `ruff` is safe there because it is a Rust binary. Libraries
  belong in `pyproject.toml`.
- **devenv's Python module owns the interpreter wiring.** Do not set
  `UV_PYTHON`, `UV_PYTHON_DOWNLOADS` or `LD_LIBRARY_PATH` in `devenv.nix`;
  `languages.python` ties `uv` to the nixpkgs interpreter and manages that
  wiring itself.
- **`.envrc` puts `.venv/bin` on `PATH`**, so under direnv `pytest` and
  `uv run pytest` are the same pytest. Under a bare `devenv shell` they are
  not: `.venv/bin` is not on `PATH`, so bare `pytest` is *command not found*
  rather than a different, silently wrong environment. `uv run <tool>` is the
  one spelling that works either way.
- **Rename the project in `pyproject.toml`, then rename `src/myproject/`.**
  The key of `[project.scripts]` names the CLI. Nothing in `devenv.nix` reads
  any of it, so nothing there needs changing.
- **`uv.lock` is not shipped; `uv sync` writes it and you commit it.** A lock
  in the template would be a lock over somebody else's empty dependency set.
  The workflow runs `uv sync --locked`, which fails loudly if the committed
  lock is stale.
- **`devenv.lock` is not shipped either; `devenv update` writes it and you
  commit it.** Write it early. `devenv.yaml` declares one input, but devenv
  adds *itself* as a second and the lock pins both — until then devenv's own
  modules float, and the environment can change behaviour with no edit by you.
- **For editing `devenv.nix` itself, use `devenv lsp`.** It starts nixd
  already configured for this file, using the nixd bundled inside the devenv
  binary — so there is nothing to add to `packages`, and
  `devenv lsp --print-config` shows what it hands nixd.
- **After an update moves `python3`**, `.venv` points at a store path that no
  longer exists: `rm -rf .venv && uv sync`.
- **There is no `nix fmt` here.** A flake template gets a `formatter` output;
  this one has no flake to hang it on. `ruff format` covers the Python side,
  and devenv can run git hooks — see
  [devenv.sh/git-hooks](https://devenv.sh/git-hooks/).

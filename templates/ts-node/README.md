# ts-node

devenv environment for Node.js with TypeScript, already configured.

```bash
nix flake init -t 'github:Marcus441/nix-templates#ts-node'
git init && git add -A
devenv shell               # or: direnv allow
npm install
```

## Requirements

**devenv, installed** — https://devenv.sh. There is no `flake.nix` here, so
`nix develop` does not apply. `nix profile install nixpkgs#devenv` is enough.

## What you get

- `nodejs_24` — `node`, `npm`, `npx` and `corepack` all ship inside it
- TypeScript with the language server wired up, via `languages.typescript`
- two tsconfigs that each do one job: `tsconfig.json` typechecks `src` **and**
  `test`, `tsconfig.build.json` emits `src` to `dist/`
- a `src/index.ts` and a `test/example.test.ts` to delete
- `devenv test`, which runs `npm ci`, the vitest suite and the build
- a GitHub Actions workflow that runs `devenv test` on Linux and macOS and
  typechecks

## Building

```bash
npm ci             # install exactly what package-lock.json says
npm run build      # tsc -p tsconfig.build.json -> dist/
npm run dev        # tsx src/index.ts, no build step
npm run typecheck  # tsc -p tsconfig.json, covers the tests too
```

The build-shaped command for the environment as a whole is `devenv test`, which
builds the environment, then runs `npm ci`, `npm test` and `npm run build`:

```bash
devenv test
```

It talks to the npm registry, so it needs the network — `devenv test` is not
sandboxed.

## Testing

```bash
npm test           # vitest run — terminates
npm run test:watch # vitest in watch mode
```

## Changing the Node version

One line in `devenv.nix`:

```nix
package = pkgs.nodejs_24;   # nodejs_22 | nodejs_24 | nodejs_26
```

Pinning a major is deliberate — an EOL release is removed from nixpkgs rather
than left to rot, so the version you get is one you can still patch.

## Notes

- **The two tsconfigs are not redundant.** `include` in the base config covers
  `test/`, so your editor and `npm run typecheck` see the tests; `noEmit` keeps
  it from writing anything. `tsconfig.build.json` narrows `include` back to
  `src` and turns emit on, which is why it needs its own `rootDir`. A single
  config cannot do both: `rootDir: "src"` with `test/` included is a tsc error.
- **`moduleResolution: "nodenext"` requires the `.js` extension** on relative
  imports, even from a `.ts` file — `../src/index.js`, not `../src/index`. That
  is ESM, not a typo.
- **`package-lock.json` is committed, and `npm ci` installs exactly what it
  says or fails.** `devenv test` and CI both install with `npm ci`, so the lock
  is the record of what was tested. `npm install` updates it when you change a
  dependency.
- `files` in `package.json` is an allow-list: `npm pack` ships `dist/` and
  nothing else, so adding a directory cannot silently publish it.
- npm ships inside the `nodejs` derivation; there is no separate package for it.
  `pkgs.nodePackages` no longer exists in nixpkgs, so install CLI tools from the
  top level (`packages = [pkgs.<tool>];` in `devenv.nix`) or as project
  devDependencies.
- `.envrc` adds `node_modules/.bin` to `PATH`, so locally-installed CLIs resolve
  without `npx`.
- **`devenv.lock` is not shipped; `devenv update` writes it and you commit it.**
  Write it early. `devenv.yaml` declares one input, but devenv adds *itself* as
  a second and the lock pins both — until then devenv's own modules float, and
  the environment can change behaviour with no edit by you.
- **For editing `devenv.nix` itself, use `devenv lsp`.** It starts nixd already
  configured for this file, using the nixd bundled inside the devenv binary —
  so there is nothing to add to `packages`, and `devenv lsp --print-config`
  shows what it hands nixd.

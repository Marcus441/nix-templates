# ts-node

Dev environment for Node.js with TypeScript, already configured.

```bash
nix flake init -t 'github:Marcus441/nix-templates#ts-node'
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
npm install
```

## What you get

- `nodejs_24` — `node`, `npm`, `npx` and `corepack` all ship inside it
- two tsconfigs that each do one job: `tsconfig.json` typechecks `src` **and**
  `test`, `tsconfig.build.json` emits `src` to `dist/`
- a `src/index.ts` and a `test/example.test.ts` to delete
- a `packages.default` built by `buildNpmPackage`, running vitest in its check
  phase
- a GitHub Actions workflow that builds on Linux and macOS and typechecks

## Building

```bash
npm run build      # tsc -p tsconfig.build.json -> dist/
npm run dev        # tsx src/index.ts, no build step
npm run typecheck  # tsc -p tsconfig.json, covers the tests too
```

Or build the Nix package, which runs `npm ci`, `npm run build` and the tests in
a sandbox:

```bash
nix build
```

## Testing

```bash
npm test           # vitest run — terminates
npm run test:watch # vitest in watch mode
```

## Changing the Node version

One line in `flake.nix`:

```nix
packages = [pkgs.nodejs_24];   # nodejs_22 | nodejs_24 | nodejs_26
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
- **`package-lock.json` is committed, and `nix build` depends on it.**
  `buildNpmPackage` fetches dependencies as a fixed-output derivation keyed by
  `npmDepsHash` in `flake.nix`. After changing any dependency, refresh both:

  ```bash
  npm install --package-lock-only
  nix run 'nixpkgs#prefetch-npm-deps' -- package-lock.json
  ```

  Paste the printed hash into `npmDepsHash`. A stale hash fails the build with
  the correct one in the error, so you can also just build and copy it.
- **`buildNpmPackage` has no check hook**, so the `checkPhase` is written out.
  `doCheck = true` on its own runs nothing — the generic builder finds no
  Makefile and skips.
- `pname` and `version` come from `package.json` via `builtins.fromJSON`, so
  renaming the project is one edit rather than two that can drift.
- `files` in `package.json` is an allow-list: `npm pack` ships `dist/` and
  nothing else, so adding a directory cannot silently publish it.
- npm ships inside the `nodejs` derivation; there is no separate package for it.
  `pkgs.nodePackages` no longer exists in nixpkgs, so install CLI tools from the
  top level (`pkgs.typescript-language-server`) or as project devDependencies.
- `.envrc` adds `node_modules/.bin` to `PATH`, so locally-installed CLIs resolve
  without `npx`.
- `nix fmt` formats `flake.nix` with alejandra.

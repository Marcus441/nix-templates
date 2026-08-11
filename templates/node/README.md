# node

Dev environment for Node.js, with TypeScript already configured.

```bash
nix flake init -t github:Marcus441/nix-templates#node
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
npm install
```

## What you get

- `nodejs_24` — `node`, `npm`, `npx` and `corepack` all ship inside it
- `tsconfig.json` plus a `tsconfig.build.json` for emitting to `dist/`
- a `src/index.ts` and a `test/example.test.ts` to delete

## Building

```bash
npm run build      # tsc -> dist/
npm run dev        # tsx src/index.ts, no build step
```

Or build the Nix package, which runs `npm ci` and `npm run build` in a sandbox:

```bash
nix build
```

## Testing

```bash
npm test           # vitest
```

## Changing the Node version

One line in `flake.nix`:

```nix
packages = [pkgs.nodejs_24];   # nodejs_22 | nodejs_24 | nodejs_26
```

Pinning a major is deliberate — an EOL release is removed from nixpkgs rather
than left to rot, so the version you get is one you can still patch.

## Notes

- **`package-lock.json` is committed, and `nix build` depends on it.**
  `buildNpmPackage` fetches dependencies as a fixed-output derivation keyed by
  `npmDepsHash` in `flake.nix`. After changing any dependency, refresh both:

  ```bash
  npm install --package-lock-only
  nix run nixpkgs#prefetch-npm-deps -- package-lock.json
  ```

  Paste the printed hash into `npmDepsHash`. A stale hash fails the build with
  the correct one in the error, so you can also just build and copy it.
- npm ships inside the `nodejs` derivation; there is no separate package for it.
  `pkgs.nodePackages` no longer exists in nixpkgs, so install CLI tools from the
  top level (`pkgs.typescript-language-server`) or as project devDependencies.
- `.envrc` adds `node_modules/.bin` to `PATH`, so locally-installed CLIs resolve
  without `npx`.
- `nix fmt` formats `flake.nix` with alejandra.

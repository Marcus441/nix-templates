# node

Node.js and TypeScript dev shell.

```bash
nix flake init -t github:Marcus441/nix-templates#node
git init && git add -A     # flakes see only tracked files
nix develop
npm install
```

## What you get

- `nodejs_24` — `node`, `npm`, `npx` and `corepack` all ship inside it
- `tsconfig.json` plus a `tsconfig.build.json` for emitting to `dist/`
- a `src/index.ts` and a `test/example.test.ts` to delete

## Changing the Node version

One line in `flake.nix`:

```nix
nodejs = pkgs.nodejs_24;   # nodejs_22 | nodejs_24 | nodejs_26
```

Pinning a major is deliberate — an EOL release is removed from nixpkgs rather
than left to rot, so the version you get is one you can still patch.

## Notes

- There is no `packages` output; this template is a dev shell only. Build with
  `npm run build`.
- `pkgs.nodePackages` no longer exists in nixpkgs. Install CLI tools from the
  top level (`pkgs.typescript-language-server`) or as project devDependencies.

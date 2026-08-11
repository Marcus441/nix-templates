# ts-node-rest-api

Dev environment for a TypeScript REST API on Node.js — Express 5 and a
middleware layout that is already wired up.

```bash
nix flake init -t github:Marcus441/nix-templates#ts-node-rest-api
git init && git add -A     # flakes see only tracked files
nix develop                # or: direnv allow
npm install
npm run dev
```

## What you get

```
src/index.ts              server bootstrap, middleware registration
src/config/config.ts      env-backed config (dotenv), plus requireEnv
src/middleware/
  corsHandler.ts          CORS
  loggingHandler.ts       request logging
  errorHandler.ts         error -> response mapping
  routeNotFound.ts        404 fallback, registered last
test/index.test.ts        supertest + vitest
vitest.config.ts          test include patterns and v8 coverage
```

Dependencies: `express` and `dotenv`. Dev: `vitest` with v8 coverage,
`supertest`, `tsx`, `nodemon`, `typescript`.

Two tsconfigs, each doing one job: `tsconfig.json` typechecks `src`, `test` and
the vitest config; `tsconfig.build.json` emits `src` to `dist/`.

## Building

```bash
npm run build      # tsc -p tsconfig.build.json -> dist/
npm run dev        # tsx src/index.ts, no build step
npm start          # nodemon, config in nodemon.json
npm run typecheck  # tsc -p tsconfig.json, covers the tests too
```

Or build the Nix package, which runs `npm ci`, `npm run build` and the tests in
a sandbox:

```bash
nix build
```

## Testing

```bash
npm test            # vitest run — terminates
npm run test:watch  # vitest in watch mode
npm run test:coverage
```

The suite runs on a freshly initialised project with no `.env` present. Keep it
that way: a template whose tests cannot run until you have guessed the right
environment variables is a template nobody can verify.

## Configuration

`src/config/config.ts` reads `.env` through dotenv and exports plain constants.
Everything has a default, so nothing is required to start.

To make a variable genuinely required, use the exported helper — it fails at
import time rather than at the first request that needs it:

```ts
export const DATABASE_URL = requireEnv("DATABASE_URL");
```

## Notes

- Middleware order matters: `routeNotFound` must stay registered last, and
  `errorHandler` after the routes it catches for.
- **`moduleResolution: "nodenext"` requires the `.js` extension** on relative
  imports, even from a `.ts` file — `../src/index.js`, not `../src/index`. And
  with `verbatimModuleSyntax`, type-only imports must say so: Express's
  `Request`, `Response` and `NextFunction` are types, so they are imported with
  `import type`.
- **`package-lock.json` is committed, and `nix build` depends on it.**
  `buildNpmPackage` fetches dependencies as a fixed-output derivation keyed by
  `npmDepsHash` in `flake.nix`. After changing any dependency, refresh both:

  ```bash
  npm install --package-lock-only
  nix run nixpkgs#prefetch-npm-deps -- package-lock.json
  ```

  Paste the printed hash into `npmDepsHash`. A stale hash fails the build with
  the correct one in the error, so you can also just build and copy it.
- **`buildNpmPackage` has no check hook**, so the `checkPhase` is written out.
  `doCheck = true` on its own runs nothing — the generic builder finds no
  Makefile and skips.
- `pname` and `version` come from `package.json` via `builtins.fromJSON`, so
  renaming the project is one edit rather than two that can drift.
- npm ships inside the `nodejs` derivation; there is no separate package for it.
  Change the Node major on one line in `flake.nix`.
- `.envrc` adds `node_modules/.bin` to `PATH`, so locally-installed CLIs resolve
  without `npx`.
- `nix fmt` formats `flake.nix` with alejandra.

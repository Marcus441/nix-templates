# ts-node-rest-api

Dev environment for a Node.js REST API — Express 5, TypeScript, and a middleware
layout that is already wired up.

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
src/config/config.ts      env-backed config (dotenv)
src/middleware/
  corsHandler.ts          CORS
  loggingHandler.ts       request logging
  errorHandler.ts         error -> response mapping
  routeNotFound.ts        404 fallback, registered last
test/index.test.ts        supertest + vitest
```

Dependencies: `express`, `cors`, `dotenv`, `jsonwebtoken`,
`express-fileupload`. Dev: `vitest` with v8 coverage, `supertest`, `tsx`,
`nodemon`.

## Building

```bash
npm run build      # tsc -> dist/
npm run dev        # tsx src/index.ts, no build step
npm start          # nodemon, config in nodemon.json
```

Or build the Nix package, which runs `npm ci` and `npm run build` in a sandbox:

```bash
nix build
```

## Testing

```bash
npm test           # vitest --coverage
```

## Notes

- Middleware order matters: `routeNotFound` must stay registered last, and
  `errorHandler` after the routes it catches for.
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
  Change the Node major on one line in `flake.nix`.
- `.envrc` adds `node_modules/.bin` to `PATH`, so locally-installed CLIs resolve
  without `npx`.
- `nix fmt` formats `flake.nix` with alejandra.

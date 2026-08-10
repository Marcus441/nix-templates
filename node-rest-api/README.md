# node-rest-api

Node.js REST API dev shell — Express 5, TypeScript, and a middleware layout
that is already wired up.

```bash
nix flake init -t github:Marcus441/nix-templates#node-rest-api
git init && git add -A     # flakes see only tracked files
nix develop
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

## Scripts

| | |
| --- | --- |
| `npm run dev` | `tsx src/index.ts` — run without a build step |
| `npm start` | `nodemon`, config in `nodemon.json` |
| `npm run build` | `tsc` to `dist/` via `tsconfig.build.json` |
| `npm test` | `vitest --coverage` |

## Notes

- Middleware order matters: `routeNotFound` must stay registered last, and
  `errorHandler` after the routes it catches for.
- There is no `packages` output; this template is a dev shell only.
- `nodejs_24` provides `node`, `npm` and `npx`. Change the major on one line in
  `flake.nix`.

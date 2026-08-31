# Deployment parity only — local development runs under devenv, not this image.
# Build from the repository root: the compose file passes `context: .`.
# `npm install`, not `npm ci`: the template ships no lockfile — once you have
# committed yours, switch this to `npm ci`.
FROM node:22-alpine AS build
WORKDIR /src
COPY package.json ./
COPY apps/web/package.json apps/web/
COPY packages/contracts/package.json packages/contracts/
RUN npm install
COPY packages/contracts packages/contracts
COPY apps/web apps/web
RUN npm run build --workspace apps/web

FROM nginx:alpine
COPY infra/docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/apps/web/dist /usr/share/nginx/html

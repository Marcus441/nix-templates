# Deployment parity only — local development runs under devenv, not this image.
# Build from the repository root: the compose file passes `context: .`.
FROM golang:1.25-alpine AS build
WORKDIR /src
COPY apps/api apps/api
WORKDIR /src/apps/api
RUN CGO_ENABLED=0 go build -o /out/api ./cmd/api

FROM gcr.io/distroless/static-debian12
COPY --from=build /out/api /api
EXPOSE 5080
ENTRYPOINT ["/api", "-addr", "0.0.0.0:5080"]

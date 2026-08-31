# Convenience wrappers for the Go half; run them inside the devenv shell so
# go and psql are the same ones the processes use. `make migrate` applies
# db/migrations in order — startup does not depend on it, docs/architecture.md
# explains why.
.PHONY: run test build migrate

run:
	go run ./cmd/api -addr 127.0.0.1:5080

test:
	go test ./...

build:
	go build -o bin/api ./cmd/api

migrate:
	for f in db/migrations/*.sql; do psql -v ON_ERROR_STOP=1 -d app -f "$$f"; done

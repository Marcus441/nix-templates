package main

import (
	"context"
	"encoding/json"
	"flag"
	"log"
	"net/http"

	"github.com/jackc/pgx/v5"

	"app/internal/items"
)

// devenv exports the libpq environment, so an empty host lets pgx find the
// unix socket on its own; under docker-compose the same PG* variables carry
// the hostname and credentials instead.
const connString = "dbname=app"

func main() {
	addr := flag.String("addr", "127.0.0.1:5080", "address to listen on")
	flag.Parse()

	store := items.NewStore(connString)
	if err := store.EnsureSchema(context.Background()); err != nil {
		log.Fatalf("ensure schema: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", health)
	items.NewHandler(store).Register(mux)

	log.Printf("listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, mux))
}

func health(w http.ResponseWriter, r *http.Request) {
	conn, err := pgx.Connect(r.Context(), connString)
	if err != nil {
		http.Error(w, err.Error(), http.StatusServiceUnavailable)
		return
	}
	defer conn.Close(context.Background())

	var db int
	if err := conn.QueryRow(r.Context(), "select 1").Scan(&db); err != nil {
		http.Error(w, err.Error(), http.StatusServiceUnavailable)
		return
	}

	response := struct {
		Status string `json:"status"`
		DB     int    `json:"db"`
	}{Status: "ok", DB: db}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("encode: %v", err)
	}
}

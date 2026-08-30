package main

import (
	"context"
	"encoding/json"
	"flag"
	"log"
	"net/http"

	"github.com/jackc/pgx/v5"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:5080", "address to listen on")
	flag.Parse()

	// devenv exports the libpq environment, so an empty host lets pgx find the
	// unix socket on its own. Delete this endpoint once you have your own.
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		conn, err := pgx.Connect(r.Context(), "dbname=app")
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

		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(map[string]int{"db": db}); err != nil {
			log.Printf("encode: %v", err)
		}
	})

	log.Printf("listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, nil))
}

package items

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
)

type createItemRequest struct {
	Name string `json:"name"`
}

// Handler serves the /items routes. Error bodies are JSON strings, because
// that is what packages/contracts/openapi.yaml declares for a 400.
type Handler struct {
	store *Store
}

func NewHandler(store *Store) *Handler {
	return &Handler{store: store}
}

func (h *Handler) Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /items", h.list)
	mux.HandleFunc("POST /items", h.create)
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	items, err := h.store.List(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	var request createItemRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeJSON(w, http.StatusBadRequest, "body must be JSON")
		return
	}

	name, ok := NormalizeName(request.Name)
	if !ok {
		writeJSON(w, http.StatusBadRequest, "name must not be empty")
		return
	}

	item, err := h.store.Add(r.Context(), name)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Location", fmt.Sprintf("/items/%d", item.ID))
	writeJSON(w, http.StatusCreated, item)
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(value); err != nil {
		log.Printf("encode: %v", err)
	}
}

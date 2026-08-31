package items

import (
	"context"

	"github.com/jackc/pgx/v5"
)

// Item is the one resource this template ships; its JSON shape is declared in
// packages/contracts/openapi.yaml.
type Item struct {
	ID   int32  `json:"id"`
	Name string `json:"name"`
}

// Store opens a connection per call, which is as much pooling as one dev-loop
// resource needs; reach for pgxpool when real traffic arrives.
type Store struct {
	connString string
}

func NewStore(connString string) *Store {
	return &Store{connString: connString}
}

func (s *Store) EnsureSchema(ctx context.Context) error {
	conn, err := pgx.Connect(ctx, s.connString)
	if err != nil {
		return err
	}
	defer conn.Close(context.Background())

	_, err = conn.Exec(ctx,
		"CREATE TABLE IF NOT EXISTS items (id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY, name text NOT NULL)")
	return err
}

func (s *Store) List(ctx context.Context) ([]Item, error) {
	conn, err := pgx.Connect(ctx, s.connString)
	if err != nil {
		return nil, err
	}
	defer conn.Close(context.Background())

	rows, err := conn.Query(ctx, "SELECT id, name FROM items ORDER BY id")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []Item{}
	for rows.Next() {
		var item Item
		if err := rows.Scan(&item.ID, &item.Name); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (s *Store) Add(ctx context.Context, name string) (Item, error) {
	conn, err := pgx.Connect(ctx, s.connString)
	if err != nil {
		return Item{}, err
	}
	defer conn.Close(context.Background())

	var id int32
	if err := conn.QueryRow(ctx,
		"INSERT INTO items (name) VALUES ($1) RETURNING id", name).Scan(&id); err != nil {
		return Item{}, err
	}
	return Item{ID: id, Name: name}, nil
}

-- 0001: the items table. The API runs this same statement at startup
-- (CREATE TABLE IF NOT EXISTS), so applying migrations is not required to
-- boot; this directory is where schema work beyond the first table goes,
-- as numbered files applied in order by `make migrate`.
CREATE TABLE IF NOT EXISTS items (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text NOT NULL
);

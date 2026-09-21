# Init scripts

This folder is mounted read-only at `/docker-entrypoint-initdb.d`. The official
Postgres entrypoint runs what it finds here **once, on the very first start**, while
the data directory is still empty.

They do not run again on a volume that already holds a database. Editing a script,
or adding one, changes nothing until the data is gone.

To re-run them — this deletes every database in this topology:

```sh
docker compose down -v
docker compose up -d --wait
```

## Adding a script

- Executed: `*.sql`, `*.sql.gz`, `*.sql.xz`, `*.sql.zst`, `*.sh`. Anything else is
  logged as `ignoring …` and skipped, which is why the example here ends in
  `.sql.example` and why this README is left alone.
- Files run in filename order, so prefix them: `01-…`, `02-…`.
- SQL runs as `POSTGRES_USER` against `POSTGRES_DB` (`dev` / `dev` by default).
- `.sh` files must use LF line endings. CRLF breaks them inside the container;
  `.gitattributes` in this repository already enforces LF.
- The mount is read-only, so a script cannot modify this folder.

Start from `01-example.sql.example`: copy it to `01-example.sql`, uncomment what you
need, then reset as above.

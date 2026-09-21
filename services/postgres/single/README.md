# postgres / single

One PostgreSQL server, reachable from the host on port 5432. Default version 18,
also verified on 17.

Development only: default credentials, no TLS, no backups.

## Quick start

Standalone, from this folder:

```sh
docker network create tambat     # once per machine
cp .env.example .env
docker compose up -d --wait
./test.sh                        # optional: prove it works
```

With the CLI, from the repository root:

```sh
./tambat up postgres
./tambat test postgres
```

## Connecting

From the host:

```
postgresql://dev:dev@localhost:5432/dev
```

```sh
psql postgresql://dev:dev@localhost:5432/dev
```

From another container on the shared `tambat` network, where the service name is the
hostname and the port is the container's own:

```
postgresql://dev:dev@postgres:5432/dev
```

No psql on the host? Use the one in the container:

```sh
docker compose exec postgres psql -U dev -d dev
```

## Configuration

Every value lives in `.env` (copied from `.env.example`, gitignored):

| Variable | Default | What it does |
|---|---|---|
| `POSTGRES_VERSION` | `18` | Major version of the official image. Each version gets its own data volume. |
| `POSTGRES_PORT` | `5432` | Host port, always bound to `127.0.0.1`. Change it if the port is taken. |
| `POSTGRES_USER` | `dev` | Superuser, created on first start. |
| `POSTGRES_PASSWORD` | `dev` | Its password. |
| `POSTGRES_DB` | `dev` | Database created on first start. |
| `POSTGRES_SHM_SIZE` | `256mb` | Size of `/dev/shm`. Docker's 64MB default is too small for parallel queries. |

Changing a variable takes effect on the next `docker compose up -d --wait`, except
for `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` and anything in `init/`:
those only apply when the database is created, so changing them needs a reset.

SQL and shell scripts in [`init/`](init/) run once, on first start, while the data
directory is still empty — never again on an existing volume. See
[`init/README.md`](init/README.md).

## Where the data lives

In a named volume, `tambat-postgres-single-<version>-data`, mounted at
`/var/lib/postgresql/data`, with `PGDATA` pinned to `pgdata` inside it.

The version is part of the volume name on purpose: switching `POSTGRES_VERSION` gives
you a separate, empty database rather than a data directory the server cannot read.
Switching back finds the old one intact.

`compose.yaml` also mounts a tmpfs over `/var/lib/postgresql`, the postgres user's
home directory. Nothing worth keeping is stored there. It is there because
`postgres:18` declares that path as a volume, and without the tmpfs Docker would
attach a throwaway anonymous volume to every container it creates.

## Platform notes

- **Apple Silicon:** the official image is published for arm64, so it runs natively.
- **WSL2:** keep the repository in the Linux filesystem (`~/…`), not under `/mnt/c`.
  Bind mounts across `/mnt/c` are slow and break file permissions.
- **Port 5432 already in use**, usually by a Postgres installed on the host:
  `docker compose up` fails with a bind error. Set `POSTGRES_PORT` in `.env` to
  something else, for example `5433`.

## Reset

Stop the server, keep the data:

```sh
docker compose down
```

Delete the data, including everything `init/` created:

```sh
docker compose down -v
```

With the CLI: `./tambat down postgres` and `./tambat reset postgres`.

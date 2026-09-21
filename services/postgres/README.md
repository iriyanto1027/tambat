# PostgreSQL

The official [`postgres`](https://hub.docker.com/_/postgres) image, set up for local
development: start it, connect from the host, throw it away.

Development only: default credentials (`dev` / `dev`), no TLS, no backups.

## Topologies

| Topology | What it runs | Description |
|---|---|---|
| [`single`](single/) | One server | PostgreSQL, single node |

`single` is the default: `./tambat up postgres` is the same as
`./tambat up postgres/single`.

More topologies, `replication` first, are planned in [`../../docs/ROADMAP.md`](../../docs/ROADMAP.md).

## Versions

`POSTGRES_VERSION` in the topology's `.env` picks the major version; it defaults to
`18` and is tested on 17 and 18. Each version keeps its own data volume, so switching
versions gives you a separate, empty database instead of a data directory the server
cannot read.

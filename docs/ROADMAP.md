# Roadmap

**tambat** (Indonesian for "to moor a boat"): development-only Docker Compose setups for local backing services. One command, on WSL2, Ubuntu, and macOS.

Principle: build the foundation first. Services and topologies grow later, pulled in by real demand.

## Decisions

| Area | Decision | Why |
|---|---|---|
| Name | `tambat`: CLI `./tambat`, resource prefix `tambat-`, shared network `tambat` | Unique, short to type, and ready to become the command name if a global install is added |
| Audience | Public, open source | Useful to anyone who wants one-command local setup |
| Layout | `services/<service>/<topology>/`, with `single` as the default | Replication and cluster variants can be added without restructuring |
| Distribution (v0.1) | Clone the repo, run `./tambat` | Simplest to ship; the CLI is path-independent, so a global install can come later |
| Usage without CLI | Every topology works with plain `docker compose` | People copy single folders into their own projects |
| Primary target | Apps running on the host | The most common local-dev setup |
| Images | Official images only; no Bitnami, no official MinIO | Bitnami moved versioned tags to an unmaintained legacy repo; MinIO removed its images from Docker Hub |
| Platforms | WSL2, Ubuntu, macOS (Intel and Apple Silicon) | |
| License | MIT | Shortest permissive licence; nothing here needs a patent grant |
| CI | GitHub Actions on Ubuntu amd64 + arm64; macOS and WSL tested manually | Hosted macOS runners can't run Docker reliably |
| Terminology | primary / replica | |

## Open questions

| Question | Decide by |
|---|---|
| Second service to validate the contract: `mongodb/single` or `redis/single` | Start of v0.2 |
| Global install: brew, curl script, or none | After v0.2 |
| Host address strategy for multi-node MongoDB and Redis Cluster | Start of v0.3 (spike) |
| S3-compatible storage to replace MinIO: Garage, SeaweedFS, RustFS, Chainguard's MinIO build, or a community fork | When object storage is added |

## v0.1: Foundation

Goal: fresh clone → `./tambat up postgres` → connect from the host, on all three platforms.

**Repository**
- [ ] `README.md`: pitch, quick start, supported platforms, dev-only disclaimer, service table
- [x] `LICENSE`
- [x] `.gitattributes` (`* text=auto eol=lf`), `.gitignore` (`services/**/.env`), `.editorconfig`
- [ ] `templates/topology/` containing every contract file

**CLI**
- [ ] `./tambat` with `list`, `up`, `down`, `reset`, `logs`, `ps`, `info`, `test`, `doctor`
- [ ] Target resolution with `single` as default; auto `.env`; auto-created `tambat` network; one-topology-per-service guard; `up --wait`
- [ ] Caller environment wins over `.env`
- [ ] bash 3.2 compatible, `shellcheck` clean

**Services**
- [ ] `postgres/single`: default `POSTGRES_VERSION=18`, verified on 17 and 18

**Quality**
- [ ] `make lint`, `make test-all`
- [ ] CI: auto-discovered topologies × amd64/arm64, plus a Postgres version matrix
- [ ] Manual platform checklist passed (see below)

Exit criteria:
- CI is green.
- The manual checklist passes on every platform.
- A new topology can be added by copying the template, without touching the CLI.

## v0.2: Validate the foundation

Goal: prove the contract is generic. It must work for a multi-node topology and for a different kind of service.

- [ ] `postgres/replication`: 1 primary + 1 replica (streaming replication). Test: write on primary, read on replica, replica rejects writes.
- [ ] One non-SQL `single`. Either `mongodb/single` (single-node replica set, which exercises init logic) or `redis/single`.
- [ ] Retro: adjust the contract, template, and `CLAUDE.md` for anything that turned out Postgres-shaped.

## v0.3: Clustering

- [ ] Spike: host address strategy for multi-node; record the decision in `CLAUDE.md`
- [ ] `mongodb/replicaset`: 3 nodes
- [ ] `redis/sentinel`
- [ ] `redis/cluster`
- [ ] `test.sh` for each of these verifies host-side usability

## Backlog

Pulled in by demand. Order within each group is rough priority.

**Next services (`single` first)**
- MySQL, MariaDB
- Redis or MongoDB (whichever wasn't done in v0.2)
- RabbitMQ
- Mailpit
- S3-compatible object storage

**More topologies**
- postgres: `ha` (Patroni + etcd), logical replication, variants (pgvector, PostGIS), PgBouncer
- mysql / mariadb: `replication`
- mongodb: `sharded`

**Later services**
- Messaging and streaming: Kafka (KRaft) or Redpanda, NATS
- Search: OpenSearch or Elasticsearch, Meilisearch, Typesense
- Keycloak
- Observability: Grafana LGTM all-in-one
- ClickHouse, Qdrant
- SQL Server (amd64-only), Oracle Free

**Tooling**
- Stacks: ready-made combinations via Compose `include`
- Optional admin UIs via Compose profiles
- Global install

## Release checklist

- [ ] CI green
- [ ] Manual platform checklist passed for every new or changed topology
- [ ] `CHANGELOG.md` updated
- [ ] Git tag + GitHub release

### Manual platform checklist

On each platform: fresh clone → `./tambat doctor` → `./tambat up <target>` → `./tambat test <target>` → connect with a client on the host → `./tambat reset <target> --yes`.

- [ ] Windows 11 + WSL2 + Docker Desktop
- [ ] Windows 11 + WSL2 + Docker Engine inside WSL
- [ ] Ubuntu LTS + Docker Engine
- [ ] macOS Apple Silicon + Docker Desktop
- [ ] macOS Apple Silicon + OrbStack or Colima
- [ ] macOS Intel (best effort)
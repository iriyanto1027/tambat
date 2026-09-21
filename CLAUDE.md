# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

**tambat** (Indonesian for "to moor a boat") is an open-source collection of Docker Compose setups for running backing services (databases, caches, queues, storage, …) locally for development. One command to start, identical behaviour on Windows (WSL2), Ubuntu, and macOS (Intel and Apple Silicon).

It is **development-only**: default credentials, no TLS, no backups. Multi-node topologies (replication, clusters) exist so developers can test application behaviour against them, not to model production.

Current milestone and scope live in `ROADMAP.md`. Do not add services or topologies outside the current milestone unless asked.

## Principles

- **Foundation first, services later.** The contract below matters more than the number of services. When in doubt, pick the simpler option.
- **Every topology folder is self-contained.** `docker compose up -d` inside the folder must work without the CLI. The CLI is a convenience layer, never a requirement.
- **Host-first.** The primary user runs their app on the host (IDE, `go run`, `npm run dev`). Everything must be reachable from the host. Access from other containers via the shared `tambat` network is secondary.
- **No new runtime dependencies.** The CLI needs only bash, Docker, and Docker Compose v2. No Python, Node, `jq`, or `yq`.
- **Official images only.** Never use Bitnami images (versioned tags were moved to an unmaintained legacy repository). Never use the official MinIO images (removed from Docker Hub); pick an alternative when object storage is added.

## Repository layout

```
.
├── tambat                     # CLI entry point (bash)
├── lib/                       # CLI helpers, sourced by ./tambat
├── services/
│   └── <service>/
│       ├── README.md          # overview + list of topologies
│       └── <topology>/        # "single" always exists and is the default
│           ├── compose.yaml
│           ├── .env.example
│           ├── meta.env
│           ├── test.sh
│           ├── init/          # optional: first-run init scripts / config
│           └── README.md
├── templates/topology/        # starting point for every new topology
├── scripts/                   # maintainer scripts (lint, CI discovery)
├── .github/workflows/
├── Makefile                   # maintainer tasks only (lint, test-all)
├── CLAUDE.md
└── ROADMAP.md
```

Topology names in use: `single`, `replication`, `ha`, `sentinel`, `cluster`, `replicaset`, `sharded`. Use primary/replica terminology, never master/slave.

Naming: the CLI is `./tambat`. Every Docker resource this repo creates is namespaced: Compose projects and volumes start with `tambat-`, and the shared network is named `tambat`.

## Topology contract (definition of done)

A topology is done when all required files exist, every rule below holds, and `./tambat test <target>` passes in CI.

### compose.yaml

- Top-level `name: tambat-<service>-<topology>`, so standalone and CLI usage get the same project name.
- No `version:` key. No `container_name`.
- Service names are the DNS names on the `tambat` network: `<service>` for single (e.g. `postgres`), `<service>-<role><n>` for multi-node (e.g. `postgres-primary`, `postgres-replica1`).
- Image tag comes from a variable: `image: postgres:${POSTGRES_VERSION}`. Pin to a major version (or major.minor where upstream breaks on minors). Never `latest`.
- Every container has a `healthcheck`. Nodes that depend on others use `depends_on: { <svc>: { condition: service_healthy } }`.
- Ports: `"127.0.0.1:${POSTGRES_PORT}:5432"`. Always bind to 127.0.0.1 (on Linux, Docker-published ports bypass UFW). Host ports always come from `.env`.
- Data lives in named volumes, never bind mounts. When the on-disk format is version-specific, include the major version in the volume name: `name: tambat-postgres-single-${POSTGRES_VERSION}-data`. Read-only bind mounts are fine for `init/` and config files.
- `extra_hosts: ["host.docker.internal:host-gateway"]` on every service (Docker Engine on Linux does not provide it).
- All services join the shared external network:
  ```yaml
  networks:
    default:
      name: tambat
      external: true
  ```

### .env.example

- Holds every tunable value: image versions, host ports, credentials, database names.
- Must be bash-sourceable: `KEY=value`, no spaces around `=`, no unquoted spaces in values.
- Defaults: credentials `dev` / `dev`; host ports equal the service's standard port.
- Committed. `.env` is gitignored.

### meta.env

Metadata for `./tambat list` and `./tambat info`. Sourced after `.env`, so values may reference `.env` variables.

```bash
DESCRIPTION="PostgreSQL, single node"
HOST_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${POSTGRES_PORT}/${POSTGRES_DB}"
NETWORK_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}"
```

`info` prints `DESCRIPTION` and every variable ending in `_URL`, so multi-node topologies can define `HOST_URL_PRIMARY`, `HOST_URL_REPLICA1`, and so on. Optional: `ADMIN_URL`.

### test.sh

- `#!/usr/bin/env bash`, `set -euo pipefail`, executable. The CLI runs it with the topology folder as working directory.
- Runs against an already-running topology. Exit 0 = pass. Finishes within about 60 seconds.
- Uses `docker compose exec -T`, so no client tools are needed on the host.
- Verifies behaviour, not just liveness. Single: a query round-trip. Replication: write on primary, read on replica, replica rejects writes.
- Multi-node topologies must also prove the topology is usable from the host side (host-first). The approach is decided per topology; see ROADMAP v0.3.
- Idempotent: running it twice in a row passes twice.

### README.md (per topology)

Sections: what it runs, quick start (CLI and standalone), connection details (host and `tambat` network), configuration (`.env` variables), platform notes, reset. Keep it short.

## CLI (`./tambat`)

| Command | Behaviour |
|---|---|
| `list` | All services and topologies with their `DESCRIPTION`. |
| `up <target>` | Copy `.env.example` to `.env` if missing; create the `tambat` network if missing; refuse if another topology of the same service is running; `docker compose up -d --wait`; print `info`. |
| `down <target>` | Stop and remove containers. Keep volumes. |
| `reset <target>` | `down -v` (deletes data). Asks for confirmation unless `--yes`. |
| `logs <target> [-f]` | Compose logs. |
| `ps` | All running `tambat-*` projects. |
| `info <target>` | `DESCRIPTION`, every `*_URL`, host ports. |
| `test <target>` | Run the topology's `test.sh`. |
| `doctor` | Docker running, Compose v2 version, CPU architecture, repo under `/mnt/c` on WSL (warn), port conflicts. |

Target format: `<service>` (means `<service>/single`) or `<service>/<topology>`. Unknown targets print the valid ones.

Implementation rules:

- **bash 3.2 compatible** (macOS default). No associative arrays, `mapfile`, `${var,,}`, `&>>`, or `|&`.
- **No GNU-only tool flags.** Avoid `sed -i`, `readlink -f`, `grep -P`, and `date -d`.
- **Locate the repo from the script's own path** (or `TAMBAT_HOME` if set), never from `$PWD`. This keeps a future global install (symlink, brew, curl) possible without restructuring.
- **One helper for every `docker compose` call.** It sets `--project-directory`, `-f`, and `--env-file` explicitly.
- **Caller environment wins over `.env`**, the same precedence Compose uses. Sourcing `.env` must not clobber variables already set in the environment; CI relies on this for version matrices.
- **Running-state checks use Compose project labels** (`com.docker.compose.project`), checking each sibling topology's project name.
- **Error messages say what failed and what to do next.**
- **`shellcheck` clean.**

## Cross-platform rules

- **Target runtimes:** Docker Desktop (Windows/WSL2, macOS), Docker Engine on Ubuntu, Docker Engine inside WSL2, OrbStack and Colima on macOS.
- **Images must support `linux/amd64` and `linux/arm64`.** If upstream is amd64-only, set `platform: linux/amd64` and state in the README that it runs under emulation on Apple Silicon.
- **All text files use LF**, enforced by `.gitattributes`. CRLF breaks shell scripts inside containers.
- **On WSL, the repo must live in the Linux filesystem** (`~/…`), not `/mnt/c/…`. `doctor` warns about this.
- **Do not rely on `network_mode: host`**; it behaves inconsistently across Docker Desktop versions.
- **Memory-hungry services** (OpenSearch, Kafka, ClickHouse) ship conservative memory defaults in `.env.example`.

## Known pitfalls

- **Postgres 18+ changed the image's default data location** (PGDATA and volume path). Handle it explicitly in `compose.yaml`, and verify in CI on both the previous major and the current one.
- **Postgres replication:** the replica bootstraps with `pg_basebackup`, so the primary must be healthy first.
- **MongoDB single must run as a single-node replica set**; otherwise transactions and change streams don't work.
- **Multi-node MongoDB and Redis Cluster advertise internal hostnames/IPs** to clients, so a host-side app cannot reach the other nodes even when every container is healthy. Solve and document this before shipping those topologies.
- **OpenSearch/Elasticsearch need `vm.max_map_count` raised** on Linux and WSL.

## Workflows

### Adding a topology

1. Copy `templates/topology/` to `services/<service>/<topology>/`. For a new service, also create `services/<service>/README.md`.
2. Fill in every file following the contract.
3. Run `make lint`.
4. Run `./tambat up <target> && ./tambat test <target> && ./tambat test <target> && ./tambat reset <target> --yes`. The test runs twice to check idempotence.
5. Update the service README's topology list and the root README's service table, and tick the item in `ROADMAP.md`.

CI discovers topologies automatically (`services/*/*/compose.yaml`); no workflow edit is needed.

### Checks

- `make lint`: `shellcheck` on `tambat`, `lib/`, `scripts/`, and every `test.sh`; `docker compose --env-file .env.example config -q` on every topology.
- `make test-all`: up, test, reset for every topology. Slow; CI runs it.

### CI

- **Architecture matrix:** GitHub Actions on `ubuntu-latest` (amd64) and `ubuntu-24.04-arm` (arm64, a stand-in for Apple Silicon), crossed with every discovered topology.
- **Version matrix:** version-sensitive services also run across versions (e.g. `POSTGRES_VERSION` 17 and 18) by setting the variable in the job environment.
- **macOS and WSL are not covered by hosted CI.** They use the manual checklist in `ROADMAP.md`, run before every release.

## Don'ts

- Don't add services or topologies outside the current milestone without being asked.
- Don't use `latest` tags, Bitnami images, or official MinIO images.
- Don't add runtime dependencies to the CLI.
- Don't bind ports to `0.0.0.0`.
- Don't commit `.env` files.
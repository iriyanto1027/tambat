#!/usr/bin/env bash
#
# Behavioural test for postgres/single. It runs against an already-running
# topology:
#
#   docker compose up -d --wait && ./test.sh
#
# Everything goes through `docker compose exec`, so no psql is needed on the host,
# and psql reads the credentials from the container's own environment, so the test
# follows whatever .env the running container was started with.
#
# Idempotent: it clears its own rows before writing and drops its own schema at the
# end, so two runs in a row both pass.

set -euo pipefail

# Locate the topology from this script's own path, never from $PWD, so the test
# also works when it is called from somewhere else.
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cd "$script_dir"

# The data directory compose.yaml pins. Check 3 fails if an image version ever
# puts the data somewhere else.
expected_pgdata=/var/lib/postgresql/data/pgdata

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'ok: %s\n' "$*"
}

# One helper for every docker compose call.
compose_exec() {
  docker compose exec -T postgres "$@"
}

# psql_sql <statement>
# Runs one statement as the configured user against the configured database and
# prints the result with no header and no padding. ON_ERROR_STOP turns a SQL error
# into a non-zero exit.
psql_sql() {
  # The single quotes are deliberate: POSTGRES_USER and POSTGRES_DB are expanded by
  # the shell inside the container, not by this one.
  # shellcheck disable=SC2016
  compose_exec sh -c \
    'exec psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -qtAc "$1"' \
    psql_sql "$1" | tr -d '\r'
}

# 1. The topology has to be up before anything else means anything.
# shellcheck disable=SC2016 # expanded inside the container, as above
if ! compose_exec sh -c 'pg_isready -h 127.0.0.1 -q -U "$POSTGRES_USER" -d "$POSTGRES_DB"'; then
  fail "postgres is not accepting connections. Start it first: docker compose up -d --wait"
fi
pass "accepting connections over TCP"

# 2. Round-trip: write a row, read it back, compare. A token unique to this run
#    proves the value made it through this time, not a leftover from an earlier one.
token="tambat-$$-$(date +%s)"

psql_sql "CREATE SCHEMA IF NOT EXISTS tambat_test" >/dev/null
psql_sql "CREATE TABLE IF NOT EXISTS tambat_test.roundtrip (
            id bigserial PRIMARY KEY,
            token text NOT NULL,
            created_at timestamptz NOT NULL DEFAULT now())" >/dev/null
psql_sql "DELETE FROM tambat_test.roundtrip" >/dev/null
psql_sql "INSERT INTO tambat_test.roundtrip (token) VALUES ('$token')" >/dev/null

read_back=$(psql_sql "SELECT token FROM tambat_test.roundtrip")
if [ "$read_back" != "$token" ]; then
  fail "wrote '$token' but read back '$read_back'"
fi
pass "wrote a row and read it back"

# 3. The data has to be on the named volume. A wrong data directory looks perfectly
#    healthy until the container is recreated and the data turns out to be gone.
data_directory=$(psql_sql "SHOW data_directory")
if [ "$data_directory" != "$expected_pgdata" ]; then
  fail "data_directory is '$data_directory', expected '$expected_pgdata'. compose.yaml pins PGDATA; check whether this image version moved it."
fi

fstype=$(compose_exec stat -f -c %T "$expected_pgdata" | tr -d '\r')
case "$fstype" in
  tmpfs | overlay | overlayfs)
    fail "$expected_pgdata is on $fstype, which does not survive the container. It must be on the named volume."
    ;;
esac
pass "data directory is $data_directory, on a persistent filesystem ($fstype)"

# 4. Leave the database as it was found.
psql_sql "SET client_min_messages TO warning;
          DROP SCHEMA IF EXISTS tambat_test CASCADE" >/dev/null
pass "cleaned up"

printf 'PASS: postgres/single\n'

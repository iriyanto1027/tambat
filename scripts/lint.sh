#!/usr/bin/env bash
#
# Static checks for the whole repository:
#   - shellcheck on the CLI, lib/, scripts/, and every test.sh
#   - docker compose config -q on every topology, using its .env.example
#
# Both checks always run, so one failure does not hide the other.
#
# Missing tools: locally they are a warning and the check is skipped, so a fresh
# clone can run `make lint` without installing anything. When CI is set they are
# an error, so a workflow can never skip a check silently.
#
# Passes with an empty repository: no CLI, no lib/, no services/ yet.

set -euo pipefail

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=${TAMBAT_HOME:-$(CDPATH='' cd -- "$script_dir/.." && pwd)}
cd "$repo_root"

status=0
shell_checked=0
topologies_checked=0

warn() {
  printf 'warning: %s\n' "$*" >&2
}

err() {
  printf 'error: %s\n' "$*" >&2
}

# missing_tool <name> <install hint>
# Error in CI, warning everywhere else. Returns 0 so the caller can skip and
# carry on with the remaining checks.
missing_tool() {
  if [ -n "${CI:-}" ]; then
    err "$1 not found, and CI is set. Install it in the workflow before running lint."
    status=1
  else
    warn "$1 not found; skipping this check."
    warn "  install: $2"
  fi
}

lint_shell() {
  local file
  local files
  local found=0
  files=()

  for file in tambat lib/*.sh scripts/*.sh services/*/*/test.sh templates/*/test.sh; do
    # An unmatched glob stays literal, so skip anything that is not a real file.
    [ -f "$file" ] || continue
    files+=("$file")
    found=$((found + 1))
  done

  if [ "$found" -eq 0 ]; then
    return 0
  fi

  if ! command -v shellcheck >/dev/null 2>&1; then
    missing_tool shellcheck \
      'apt-get install shellcheck | brew install shellcheck | https://github.com/koalaman/shellcheck#installing'
    return 0
  fi

  # Guarded: expanding an empty array under `set -u` fails on bash 3.2 (macOS).
  if [ "$found" -gt 0 ]; then
    shellcheck -x "${files[@]}" || status=1
  fi
  shell_checked=$found
}

# compose_config <topology-dir>
# The one helper for every docker compose call: project directory, compose file,
# and env file are always explicit, never inferred from the working directory.
compose_config() {
  docker compose \
    --project-directory "$1" \
    -f "$1/compose.yaml" \
    --env-file "$1/.env.example" \
    config -q
}

lint_compose() {
  local targets
  local target
  local dir

  if ! targets=$("$script_dir/list-topologies.sh"); then
    err "could not list topologies. Check scripts/list-topologies.sh."
    status=1
    return 0
  fi

  # No topology yet: nothing to check, and no reason to require Docker.
  if [ -z "$targets" ]; then
    return 0
  fi

  if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    missing_tool 'docker compose (v2)' 'https://docs.docker.com/compose/install/'
    return 0
  fi

  while IFS= read -r target; do
    [ -n "$target" ] || continue
    dir="services/$target"

    if [ ! -f "$dir/.env.example" ]; then
      err "$dir/.env.example is missing. Every topology must commit one."
      status=1
      continue
    fi

    compose_config "$dir" || status=1
    topologies_checked=$((topologies_checked + 1))
  done <<EOF
$targets
EOF
}

lint_shell
lint_compose

printf 'lint: checked %s shell file(s) and %s topology(ies)\n' \
  "$shell_checked" "$topologies_checked"

exit "$status"

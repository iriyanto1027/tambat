#!/usr/bin/env bash
#
# Print every topology in the repository as <service>/<topology>, one per line.
# Topologies are discovered from services/*/*/compose.yaml. CI uses this to build
# its job matrix, so the output is plain and sorted (glob order).
#
# Prints nothing and exits 0 when there is no topology yet.

set -euo pipefail

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=${TAMBAT_HOME:-$(CDPATH='' cd -- "$script_dir/.." && pwd)}
cd "$repo_root"

for compose_file in services/*/*/compose.yaml; do
  # An unmatched glob stays literal, so skip anything that is not a real file.
  [ -f "$compose_file" ] || continue

  topology_dir=${compose_file%/compose.yaml} # services/<service>/<topology>
  printf '%s\n' "${topology_dir#services/}"
done

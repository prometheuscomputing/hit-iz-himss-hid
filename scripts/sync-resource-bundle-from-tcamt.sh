#!/usr/bin/env bash
# Export from TCAMT API (optional) or process a local exportRBZip archive.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$#" -ge 1 ] && [ -f "$1" ]; then
    exec bash "${ROOT_DIR}/scripts/process-tcamt-resource-bundle.sh" "$@"
fi

cat <<EOF
Usage:
  bash scripts/sync-resource-bundle-from-tcamt.sh [process-options] <export.zip>

Drop your TCAMT exportRBZip at tcamt-export/resources.zip, then:

  bash scripts/publish-tcamt-resource-bundle.sh
  git push origin himss

Or process manually:

  bash scripts/process-tcamt-resource-bundle.sh --apply --bump-version tcamt-export/resources.zip

Pushing an updated tcamt-export/resources.zip to branch himss also triggers
.github/workflows/sync-tcamt-resource-bundle.yml (process + commit + build).

See tcamt-export/README.md for details.
EOF
exit 1

#!/usr/bin/env bash
# Drop-in workflow: replace tcamt-export/resources.zip and run this script.
# Processes the zip, bumps resourceBundleVersion, commits, and pushes to trigger CI deploy.
#
# Usage:
#   bash scripts/publish-tcamt-resource-bundle.sh [path/to/export.zip]
#
# If no zip path is given, uses tcamt-export/resources.zip in the repo root.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ZIP_PATH="${1:-${ROOT_DIR}/tcamt-export/resources.zip}"
CANONICAL="${ROOT_DIR}/tcamt-export/resources.zip"

if [ ! -f "$ZIP_PATH" ]; then
    echo "ERROR: TCAMT export zip not found: $ZIP_PATH" >&2
    echo "Export from TCAMT (exportRBZip) and copy the zip here, or pass a path." >&2
    exit 1
fi

mkdir -p "$(dirname "$CANONICAL")"
if [ "$(cd "$(dirname "$ZIP_PATH")" && pwd)/$(basename "$ZIP_PATH")" != "$(cd "$(dirname "$CANONICAL")" && pwd)/$(basename "$CANONICAL")" ]; then
    cp -f "$ZIP_PATH" "$CANONICAL"
    echo "==> Updated tcamt-export/resources.zip"
fi

bash "${ROOT_DIR}/scripts/process-tcamt-resource-bundle.sh" \
    --apply \
    --bump-version \
    "$CANONICAL"

git add \
    tcamt-export/resources.zip \
    hit-iz-resource/src/main/resources \
    hit-iz-web/src/main/resources/app-config.properties

if git diff --staged --quiet; then
    echo "No resource changes detected after processing — nothing to commit."
    exit 0
fi

VERSION="$(grep '^app.resourceBundleVersion=' hit-iz-web/src/main/resources/app-config.properties | cut -d= -f2)"
git commit -m "$(cat <<EOF
chore: sync resource bundle from TCAMT export (${VERSION})

Automated gap-fill: organize domain, generate PDFs, merge Contextbased/Global iz content.
EOF
)"

echo "==> Committed. Push to himss to trigger build/deploy:"
echo "    git push origin himss"

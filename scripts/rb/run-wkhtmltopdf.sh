#!/usr/bin/env bash
# Wrapper: local wkhtmltopdf, or Docker on hosts where it is not installed (e.g. macOS).
set -euo pipefail

if [ "${WKHTML_USE_DOCKER:-0}" != 1 ] && command -v wkhtmltopdf >/dev/null 2>&1; then
    exec wkhtmltopdf "$@"
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: wkhtmltopdf not found and docker is unavailable." >&2
    echo "Install wkhtmltopdf or Docker, or pass --skip-pdf." >&2
    exit 127
fi

WORK_ROOT="${WKHTML_WORK_ROOT:-}"
if [ -z "$WORK_ROOT" ]; then
    for arg in "$@"; do
        if [ -f "$arg" ]; then
            WORK_ROOT="$(cd "$(dirname "$arg")" && pwd)"
            break
        fi
    done
fi

if [ -z "$WORK_ROOT" ]; then
    echo "ERROR: could not determine WKHTML_WORK_ROOT for docker wkhtmltopdf." >&2
    exit 1
fi

# Resolve file args to absolute paths under the mounted work root.
resolved=()
for arg in "$@"; do
    if [ -f "$arg" ]; then
        resolved+=("$(cd "$(dirname "$arg")" && pwd)/$(basename "$arg")")
    else
        resolved+=("$arg")
    fi
done

exec docker run --rm \
    -v "${WORK_ROOT}:${WORK_ROOT}" \
    surnet/alpine-wkhtmltopdf:3.20.2-0.12.6-small \
    "${resolved[@]}"

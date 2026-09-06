#!/usr/bin/env bash
# Fail if hit-iz-resource changed but app.resourceBundleVersion was not bumped.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_CONFIG="${ROOT_DIR}/hit-iz-web/src/main/resources/app-config.properties"
RESOURCE_DIR="hit-iz-resource/src/main/resources"

if [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ] && [ -n "${GITHUB_BASE_REF:-}" ]; then
  DIFF_RANGE="origin/${GITHUB_BASE_REF}...HEAD"
else
  DIFF_RANGE="HEAD~1..HEAD"
fi

if ! git -C "$ROOT_DIR" diff --name-only "$DIFF_RANGE" -- "$RESOURCE_DIR" | grep -q .; then
  echo "resource-bundle-version: no resource changes in ${DIFF_RANGE}" >&2
  exit 0
fi

if git -C "$ROOT_DIR" diff --name-only "$DIFF_RANGE" -- "$APP_CONFIG" | grep -q .; then
  echo "resource-bundle-version: app-config.properties updated with resource bundle changes" >&2
  exit 0
fi

echo "::error::hit-iz-resource changed but app.resourceBundleVersion was not bumped in ${APP_CONFIG}" >&2
echo "Bump app.resourceBundleVersion when publishing new test data or profiles." >&2
exit 1

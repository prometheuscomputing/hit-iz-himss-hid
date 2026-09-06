#!/usr/bin/env bash
# Build the HIMSS tool image entirely inside Docker (no host JDK/Maven/Node).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

IMAGE="${HIMSS_IMAGE:-hit-iz-himss-hid:local}"
SKIP_FRONTEND="${SKIP_FRONTEND:-0}"
PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
APP_CONFIG="${ROOT_DIR}/hit-iz-web/src/main/resources/app-config.properties"
TOOL_VERSION="$(grep '^app.version=' "$APP_CONFIG" | cut -d= -f2 | tr -d '[:space:]')"
RESOURCE_BUNDLE_VERSION="$(grep '^app.resourceBundleVersion=' "$APP_CONFIG" | cut -d= -f2 | tr -d '[:space:]')"
NO_CACHE="${NO_CACHE:-0}"

echo "Building ${IMAGE} (SKIP_FRONTEND=${SKIP_FRONTEND}, platform=${PLATFORM}, tool=${TOOL_VERSION}, resourceBundle=${RESOURCE_BUNDLE_VERSION})"

BUILD_ARGS=(
  --platform "${PLATFORM}"
  --build-arg "SKIP_FRONTEND=${SKIP_FRONTEND}"
  --build-arg "TOOL_VERSION=${TOOL_VERSION}"
  --build-arg "RESOURCE_BUNDLE_VERSION=${RESOURCE_BUNDLE_VERSION}"
  -f docker/Dockerfile
  -t "${IMAGE}"
  --load
)

if [ "$NO_CACHE" = "1" ]; then
  BUILD_ARGS=(--no-cache "${BUILD_ARGS[@]}")
fi

docker buildx build "${BUILD_ARGS[@]}" .

echo "Built ${IMAGE}"

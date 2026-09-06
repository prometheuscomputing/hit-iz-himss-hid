#!/usr/bin/env bash
# Build hit-iz-himss-hid:local — the image consumed by cert-tools-local/himss.
# Does not modify or start the cert-tools infra; only produces the Docker image.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

IMAGE_NAME="${IMAGE_NAME:-hit-iz-himss-hid}"
TAG="${TAG:-local}"
RESTART=n
PUSH=n
SKIP_FRONTEND="${SKIP_FRONTEND:-0}"
CERT_TOOLS_DIR="${CERT_TOOLS_DIR:-}"

usage() {
  cat <<'EOF'
Usage: ./build.sh [options]

Build the HIMSS tool image (hit-iz-himss-hid:local by default).
This repo only builds the image — run it with the existing cert-tools stack.

Options:
  -t TAG       Image tag (default: local)
  -s           Skip Grunt frontend build (resource/backend-only changes)
  -r           After build, recreate the tool container in CERT_TOOLS_DIR
  -p           Push IMAGE_NAME:TAG to registry (requires docker login)
  -h           Show this help

Environment:
  IMAGE_NAME        Image repository (default: hit-iz-himss-hid)
  HIMSS_IMAGE       Full image ref (default: IMAGE_NAME:TAG)
  SKIP_FRONTEND     1 to skip frontend stage (same as -s)
  CERT_TOOLS_DIR    Path to cert-tools-local/himss (required with -r)

Examples:
  ./build.sh
  SKIP_FRONTEND=1 ./build.sh -s
  CERT_TOOLS_DIR=../Certification-Infra/cert-tools-local/himss ./build.sh -r
EOF
}

while getopts ":t:srph" flag; do
  case "${flag}" in
    t) TAG=${OPTARG} ;;
    s) SKIP_FRONTEND=1 ;;
    r) RESTART=y ;;
    p) PUSH=y ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

export HIMSS_IMAGE="${HIMSS_IMAGE:-${IMAGE_NAME}:${TAG}}"
export SKIP_FRONTEND

echo "==> Building ${HIMSS_IMAGE} (SKIP_FRONTEND=${SKIP_FRONTEND})"
bash scripts/docker-build.sh

if [ "$RESTART" = "y" ]; then
  if [ -z "$CERT_TOOLS_DIR" ]; then
    echo "ERROR: set CERT_TOOLS_DIR to your cert-tools-local/himss folder (use -r)" >&2
    exit 1
  fi
  if [ ! -f "${CERT_TOOLS_DIR}/docker-compose.yml" ]; then
    echo "ERROR: no docker-compose.yml in ${CERT_TOOLS_DIR}" >&2
    exit 1
  fi
  echo "==> Recreating tool container in ${CERT_TOOLS_DIR} (infra files unchanged)"
  docker compose -f "${CERT_TOOLS_DIR}/docker-compose.yml" up -d --force-recreate tool
  echo "App: http://localhost:18085/immunization-himss/"
fi

if [ "$PUSH" = "y" ]; then
  docker push "${HIMSS_IMAGE}"
  echo "Pushed ${HIMSS_IMAGE}"
fi

echo "Done. Image: ${HIMSS_IMAGE}"
echo "Run with your existing stack:"
echo "  cd <cert-tools-local/himss> && docker compose up -d --force-recreate tool"

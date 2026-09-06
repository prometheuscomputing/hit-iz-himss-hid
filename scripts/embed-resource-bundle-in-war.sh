#!/usr/bin/env bash
# Maven resolves hit-iz-resource from Nexus during WAR packaging, ignoring the
# reactor-built jar. Replace WEB-INF/lib/hit-iz-resource-*.jar with the jar
# built from hit-iz-resource/src/main/resources in this checkout.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="$(mvn -q -DforceStdout help:evaluate -Dexpression=project.version 2>/dev/null || true)"
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
  VERSION="1.4.2-SNAPSHOT"
fi

RESOURCE_JAR="${ROOT_DIR}/hit-iz-resource/target/hit-iz-resource-${VERSION}.jar"
WAR="${ROOT_DIR}/hit-iz-web/target/immunization-himss.war"
VERIFY_PATH="Contextbased/iz/HIMSS_Immunization_Integration_Program_CDC_Modular_Test_Plan_v11/TestGroup_2/TestCase_2/TestStep_1/TestStory.html"
LIB_PATH="WEB-INF/lib/hit-iz-resource-${VERSION}.jar"

if [ ! -f "$RESOURCE_JAR" ]; then
  echo "embed-resource-bundle-in-war: missing ${RESOURCE_JAR}" >&2
  exit 1
fi
if [ ! -f "$WAR" ]; then
  echo "embed-resource-bundle-in-war: missing ${WAR}" >&2
  exit 1
fi

assert_valitheus_urls() {
  local jar_file="$1"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  (
    cd "$tmp_dir"
    jar xf "$jar_file" "$VERIFY_PATH"
    if grep -q 'nist.gov/iztool' "$VERIFY_PATH"; then
      echo "embed-resource-bundle-in-war: ${jar_file} still contains NIST tool URLs" >&2
      exit 1
    fi
    if ! grep -q 'tools.valitheus.com' "$VERIFY_PATH"; then
      echo "embed-resource-bundle-in-war: ${jar_file} missing Valitheus URLs" >&2
      exit 1
    fi
  )
  rm -rf "$tmp_dir"
}

assert_valitheus_urls "$RESOURCE_JAR"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
(
  cd "$WORKDIR"
  jar xf "$WAR"
  cp "$RESOURCE_JAR" "$LIB_PATH"
  jar cf "$WAR" .
)

(
  cd "$WORKDIR"
  rm -rf ./*
  jar xf "$WAR" "$LIB_PATH"
  if ! cmp -s "$RESOURCE_JAR" "$LIB_PATH"; then
    echo "embed-resource-bundle-in-war: embedded jar does not match ${RESOURCE_JAR}" >&2
    exit 1
  fi
)

assert_valitheus_urls "$RESOURCE_JAR"

echo "embed-resource-bundle-in-war: OK ($(wc -c < "$RESOURCE_JAR") bytes, version ${VERSION})"

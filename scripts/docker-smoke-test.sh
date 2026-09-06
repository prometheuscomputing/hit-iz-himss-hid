#!/usr/bin/env bash
# Smoke-test a built tool image against prod-like MySQL (empty schemas).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${1:?usage: docker-smoke-test.sh <image> [host-port]}"
HOST_PORT="${2:-18085}"
NET="himss-smoke-$$"
INIT_SQL="${ROOT_DIR}/docker/init/01-databases.sql"

cleanup() {
  docker rm -f smoke-app smoke-mysql >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "$NET"
docker run -d --name smoke-mysql --network "$NET" --platform linux/amd64 \
  -e MYSQL_ROOT_PASSWORD=rootpw \
  -v "${INIT_SQL}:/docker-entrypoint-initdb.d/01-databases.sql:ro" \
  mysql:8.0

echo "Waiting for MySQL"
for _ in $(seq 1 40); do
  if docker exec smoke-mysql mysqladmin ping -h127.0.0.1 -prootpw --silent >/dev/null 2>&1; then
    break
  fi
  sleep 3
done

docker run -d --name smoke-app --network "$NET" --platform linux/amd64 \
  -p "${HOST_PORT}:8080" \
  -e JAVA_OPTS="-Xmx2048m -Xms512m" \
  -e DB_HOST=smoke-mysql \
  -e DB_PORT=3306 \
  -e DB_USER=himss \
  -e DB_PASSWORD=db_password \
  -e DB_NAME=hit_himss2 \
  -e DB_ACCOUNT_NAME=hit_himss2_account \
  "$IMAGE"

echo "Waiting for Tomcat and first-boot seeding"
for _ in $(seq 1 60); do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://localhost:${HOST_PORT}/immunization-himss/" || true)"
  if [ "$code" = "200" ]; then
    domains="$(curl -s --max-time 10 "http://localhost:${HOST_PORT}/immunization-himss/api/domains" || true)"
    if echo "$domains" | grep -q '"name"'; then
      echo "Smoke test passed: http://localhost:${HOST_PORT}/immunization-himss/"
      exit 0
    fi
  fi
  sleep 5
done

echo "Smoke test failed: /immunization-himss/ did not become healthy" >&2
docker logs smoke-app 2>&1 | tail -200
exit 1

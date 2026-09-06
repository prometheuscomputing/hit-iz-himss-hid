#!/usr/bin/env bash
# Sanity checks on the built WAR before it is packaged into the image. Each of
# these has bitten a build at least once: a Grunt run that dropped web.xml (and
# with it the security filter chain), the per-tool bean config not being
# scanned, the SOAP schema missing from the classpath, and Maven quietly
# resolving an older framework than the tool was released with.
set -euo pipefail
WAR="${1:?usage: check-war.sh <war>}"
LIST="$(jar tf "$WAR")"
need() {
  if ! grep -qx "$1" <<<"$LIST"; then echo "check-war: missing $1" >&2; exit 1; fi
}
need WEB-INF/web.xml
need WEB-INF/classes/app-config.properties
need WEB-INF/classes/gov/nist/hit/core/api/config/ExtraScanFix.class
need WEB-INF/classes/gov/nist/hit/iz/web/config/IZWebBeanConfig.class
need WEB-INF/lib/hit-core-api-1.1.2-SNAPSHOT.jar
need WEB-INF/lib/hit-core-hl7v2-service-1.1.1-SNAPSHOT.jar
need WEB-INF/lib/xml-verification-1.6.5-SNAPSHOT.jar
need WEB-INF/lib/validation-proxy-1.1.1-SNAPSHOT.jar
if grep -q 'WEB-INF/lib/hit-core-api-1.1.0.jar' <<<"$LIST"; then echo "check-war: old hit-core 1.1.0 resolved" >&2; exit 1; fi
SVC="$(grep -E '^WEB-INF/lib/hit-iz-service-.*\.jar$' <<<"$LIST" | head -1)"
[ -n "$SVC" ] || { echo "check-war: no hit-iz-service jar" >&2; exit 1; }
TMP="$(mktemp -d)"
( cd "$TMP" && jar xf "$OLDPWD/$WAR" "$SVC" )
if ! jar tf "$TMP/$SVC" | grep -qx 'schema/soap.xsd'; then echo "check-war: schema/soap.xsd missing from $SVC" >&2; rm -rf "$TMP"; exit 1; fi
rm -rf "$TMP"
echo "check-war: ok ($WAR)"

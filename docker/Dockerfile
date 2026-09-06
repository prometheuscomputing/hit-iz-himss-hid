# syntax=docker/dockerfile:1.7

# Full in-container build: Node 8 frontend → Maven 8 backend → Tomcat runtime.
# Host only needs Docker. Dependencies resolve from https://nexus.valitheus.com/

ARG SKIP_FRONTEND=0
ARG TOOL_VERSION=unknown
ARG RESOURCE_BUNDLE_VERSION=dev

FROM node:8.17.0-buster AS frontend
ARG SKIP_FRONTEND=0
WORKDIR /build/hit-iz-web/client

COPY hit-iz-web/client/package.json ./
COPY hit-iz-web/client/package-lock.json* ./
COPY hit-iz-web/client/bower.json hit-iz-web/client/.bowerrc ./

RUN if [ "$SKIP_FRONTEND" = "1" ]; then \
      echo "Skipping Grunt frontend build (using committed webapp)"; \
      mkdir -p /build/hit-iz-web/src/main/webapp; \
      exit 0; \
    fi \
    && npm ci \
    && npm rebuild node-sass \
    && npm install --no-save grunt-cli@0.1.13

COPY hit-iz-web/client/ ./

RUN if [ "$SKIP_FRONTEND" = "1" ]; then exit 0; fi \
    && ./node_modules/.bin/bower install --allow-root \
    && ./node_modules/.bin/grunt build \
    && ! grep -q 'href="styles/main.css"' ../src/main/webapp/index.html \
    && test -n "$(ls ../src/main/webapp/styles/*main.css 2>/dev/null)" \
    && (grep -q LocalForageModule ../src/main/webapp/scripts/*vendor.js \
        || grep -q angular-localforage ../src/main/webapp/index.html) \
    && grep -q programbrand ../src/main/webapp/styles/*main.css \
    && test -f ../src/main/webapp/lib/angular-localforage/angular-localforage.js

FROM maven:3.9-eclipse-temurin-8 AS backend
WORKDIR /build

ARG SKIP_FRONTEND=0
ARG RESOURCE_BUNDLE_VERSION=dev

COPY pom.xml ./
COPY hit-iz-resource/pom.xml hit-iz-resource/
COPY hit-iz-domain/pom.xml hit-iz-domain/
COPY hit-iz-repo/pom.xml hit-iz-repo/
COPY hit-iz-service/pom.xml hit-iz-service/
COPY hit-iz-ws/pom.xml hit-iz-ws/
COPY hit-iz-web/pom.xml hit-iz-web/
COPY .github/maven/settings.xml /root/.m2/settings.xml

RUN echo "Building resource bundle version ${RESOURCE_BUNDLE_VERSION}"
COPY hit-iz-resource/ hit-iz-resource/
COPY hit-iz-domain/ hit-iz-domain/
COPY hit-iz-repo/ hit-iz-repo/
COPY hit-iz-service/ hit-iz-service/
COPY hit-iz-ws/ hit-iz-ws/
COPY hit-iz-web/ hit-iz-web/
COPY scripts/embed-resource-bundle-in-war.sh scripts/check-war.sh scripts/

COPY --from=frontend /build/hit-iz-web/src/main/webapp /tmp/grunt-webapp

# The Grunt output replaces src/main/webapp wholesale, and Grunt knows nothing
# about WEB-INF: without the copy below the WAR ships with no web.xml, which
# is where the Spring Security filter chain and the 120-minute session are
# declared. The framework's WebAppInitializer only registers the dispatcher
# servlet, so a WAR without web.xml comes up with no security filter at all.
RUN if [ "$SKIP_FRONTEND" = "0" ]; then \
      cp -a hit-iz-web/src/main/webapp/WEB-INF/web.xml /tmp/web.xml \
      && rm -rf hit-iz-web/src/main/webapp \
      && cp -a /tmp/grunt-webapp hit-iz-web/src/main/webapp \
      && mkdir -p hit-iz-web/src/main/webapp/WEB-INF \
      && cp -a /tmp/web.xml hit-iz-web/src/main/webapp/WEB-INF/web.xml; \
    fi \
    && rm -rf /tmp/grunt-webapp /tmp/web.xml \
    && rm -rf /root/.m2/repository/gov/nist/hit/iz/hit-iz-resource \
    && mvn -s /root/.m2/settings.xml clean install -DskipTests -B -Dexec.skip=true \
    && bash scripts/embed-resource-bundle-in-war.sh \
    && test -f hit-iz-web/target/immunization-himss.war \
    && bash scripts/check-war.sh hit-iz-web/target/immunization-himss.war

FROM tomcat:9.0.117-jdk17-temurin-noble AS runtime

ARG TOOL_VERSION=unknown
ARG RESOURCE_BUNDLE_VERSION=dev

LABEL org.opencontainers.image.title="HIMSS Immunization Test Suite" \
      org.opencontainers.image.version="${TOOL_VERSION}" \
      org.opencontainers.image.source="https://github.com/prometheuscomputing/hit-iz-himss-hid"

COPY --from=backend /build/hit-iz-web/target/immunization-himss.war /usr/local/tomcat/webapps/immunization-himss.war

# Drop invalid-session-url from the framework's security config. With it, a
# stale JSESSIONID gets a 302 to /SessionTimeout.html on every API call and
# the home page sits on its spinner after a redeploy or two idle hours.
RUN set -eux; \
    WAR=/usr/local/tomcat/webapps/immunization-himss.war; \
    ATTR=' invalid-session-url="/SessionTimeout.html"'; \
    mkdir -p /tmp/sessfix && cd /tmp/sessfix; \
    if jar tf "$WAR" | grep -qx 'WEB-INF/classes/app-security-config.xml'; then \
        F=WEB-INF/classes/app-security-config.xml; \
        jar xf "$WAR" "$F"; \
        grep -q 'session-management' "$F"; \
        sed -i "s|$ATTR||" "$F"; \
        ! grep -q 'invalid-session-url' "$F"; \
        jar uf "$WAR" "$F"; \
    else \
        jar xf "$WAR" WEB-INF/lib; \
        J=$(ls WEB-INF/lib/hit-core-api-*.jar | head -1); \
        test -n "$J"; \
        jar xf "$J" app-security-config.xml; \
        grep -q 'session-management' app-security-config.xml; \
        sed -i "s|$ATTR||" app-security-config.xml; \
        ! grep -q 'invalid-session-url' app-security-config.xml; \
        jar uf "$J" app-security-config.xml; \
        jar uf "$WAR" "$J"; \
    fi; \
    cd / && rm -rf /tmp/sessfix

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && printf 'tool=%s\nbundle=%s\n' "${TOOL_VERSION}" "${RESOURCE_BUNDLE_VERSION}" > /opt/himss-release

ENTRYPOINT ["/entrypoint.sh"]

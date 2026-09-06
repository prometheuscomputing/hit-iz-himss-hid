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
COPY scripts/embed-resource-bundle-in-war.sh scripts/

COPY --from=frontend /build/hit-iz-web/src/main/webapp /tmp/grunt-webapp

RUN if [ "$SKIP_FRONTEND" = "0" ]; then \
      rm -rf hit-iz-web/src/main/webapp \
      && cp -a /tmp/grunt-webapp hit-iz-web/src/main/webapp; \
    fi \
    && rm -rf /tmp/grunt-webapp \
    && rm -rf /root/.m2/repository/gov/nist/hit/iz/hit-iz-resource \
    && mvn -s /root/.m2/settings.xml clean install -DskipTests -B -Dexec.skip=true \
    && bash scripts/embed-resource-bundle-in-war.sh \
    && test -f hit-iz-web/target/immunization-himss.war

FROM tomcat:9.0.117-jdk17-temurin-noble AS runtime

ARG TOOL_VERSION=unknown
ARG RESOURCE_BUNDLE_VERSION=dev

LABEL org.opencontainers.image.title="HIMSS Immunization Test Suite" \
      org.opencontainers.image.version="${TOOL_VERSION}" \
      org.opencontainers.image.source="https://github.com/prometheuscomputing/hit-iz-himss-hid"

COPY --from=backend /build/hit-iz-web/target/immunization-himss.war /usr/local/tomcat/webapps/immunization-himss.war
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && printf 'tool=%s\nbundle=%s\n' "${TOOL_VERSION}" "${RESOURCE_BUNDLE_VERSION}" > /opt/himss-release

ENTRYPOINT ["/entrypoint.sh"]

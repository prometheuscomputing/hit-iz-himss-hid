# HIMSS Immunization Test Suite

HL7 v2 immunization test tool used for the HIMSS Immunization Integration Program (CDC Modular Test Plan) and related ONC testing.

This repository builds the **application image**. It does not own a specific laptop path, compose project, or host port. Those belong to whatever environment runs the image (local Docker, cert-tools, or a server).

| | |
|---|---|
| Context path | `/immunization-himss/` |
| Image (published) | `ghcr.io/prometheuscomputing/hit-iz-himss-hid` |
| Integration branch | `himss` |
| Working branch (current) | `himss-deploy` |

Branding (Valitheus / SITT / Prometheus): [BRANDING.md](BRANDING.md).  
Image build internals: [BUILD.md](BUILD.md).  
TCAMT zip input: [tcamt-export/README.md](tcamt-export/README.md).

---

## Run the image (any host)

The container listens on Tomcat **8080** inside the network. Map that to any host port you want.

Required environment:

| Variable | Purpose |
|----------|---------|
| `DB_HOST` | MySQL hostname reachable from the container |
| `DB_PORT` | MySQL port (default `3306`) |
| `DB_NAME` | App schema |
| `DB_ACCOUNT_NAME` | Account schema |
| `DB_USER` / `DB_PASSWORD` | MySQL credentials |

Example:

```bash
docker pull ghcr.io/prometheuscomputing/hit-iz-himss-hid:<tag>

docker run --rm \
  -p 8080:8080 \
  -e DB_HOST=mysql \
  -e DB_PORT=3306 \
  -e DB_NAME=hit_himss2 \
  -e DB_ACCOUNT_NAME=hit_himss2_account \
  -e DB_USER=himss \
  -e DB_PASSWORD=changeme \
  ghcr.io/prometheuscomputing/hit-iz-himss-hid:<tag>
```

Open `http://<host>:<port>/immunization-himss/`.

A compose file in another repo (for example cert-tools) should only **pull this image** and supply `DB_*`. Do not bake machine-specific paths into this repository.

First start against empty schemas takes about a minute while the tool seeds test content.

```bash
curl -s "http://<host>:<port>/immunization-himss/api/domains"
```

---

## Build from source (optional)

Needs Docker. Dependencies resolve from Valitheus Nexus.

```bash
./build.sh                 # frontend + backend → hit-iz-himss-hid:local
SKIP_FRONTEND=1 ./build.sh -s
```

To recreate a running compose service after a local build, point at **your** compose directory:

```bash
CERT_TOOLS_DIR=/path/to/your/compose ./build.sh -r
```

---

## Resource bundle and image

Three Actions. Process is manual. The published image is built from `himss` after a merge, or when you run the build Action by hand.

```
Run workflow (process)      process + bump bundle version + commit on himss-deploy

PR himss-deploy → himss     smoke build  (no GHCR)

merge into himss            build + smoke + publish GHCR + tag himss-<app.version>
  or Run workflow
```

| Workflow | Trigger | Process zip | Build + smoke | GHCR |
|----------|---------|-------------|---------------|------|
| [process-resource-bundle.yml](.github/workflows/process-resource-bundle.yml) | **Run workflow** only | Always | No | No |
| [build-himss.yml](.github/workflows/build-himss.yml) | PR into `himss` | No | Yes | No |
| [publish-himss-image.yml](.github/workflows/publish-himss-image.yml) | Push to `himss`, or **Run workflow** | No | Yes | Yes |

### 1. Process the zip on `himss-deploy`

Put a TCAMT `exportRBZip` on `himss-deploy` as `tcamt-export/resources.zip`. Then **Actions → Process resource bundle → Run workflow**. It always processes that zip (even if it did not change), organizes `Contextbased/` + `Global/` (`iz`), generates PDFs, bumps `app.resourceBundleVersion`, and commits on `himss-deploy`. It does not build the image.

You can still process on a workstation first if you want the diff in your own commit:

```bash
bash scripts/process-tcamt-resource-bundle.sh --apply --bump-version tcamt-export/resources.zip
```

`Contextfree/`, `Documentation/`, `soap/`, and `About/` are not in the TCAMT zip. Do not randomize test object IDs on an update.

### 2. Pull request into `himss`

Open `himss-deploy` → `himss`. Reviewers see the processed resource diff. The PR check smoke-builds the image and does not publish.

### 3. Build and publish from `himss`

A merge into `himss`, or **Actions → Build HIMSS image → Run workflow**, builds from `himss`, smoke-tests, and pushes `ghcr.io/prometheuscomputing/hit-iz-himss-hid`.

### Release convention

NIST shipped this tool as git tag `himss-1.9.14` and Docker Hub `nist775hit/hit-iz-himss-tool:1.9.14e`. Letter suffixes (`d`, `e`) were image rebuilds of the same tool version. We keep the `himss-<app.version>` tag and drop the letter; a rebuild of the same release is `sha-<7-char>`.

| Field | Where | Example |
|-------|--------|---------|
| Tool version | `app.version` in `hit-iz-web/src/main/resources/app-config.properties` (UI badge via `/api/appInfo`) | `1.9.15` |
| Git tag + GitHub Release | `himss-<app.version>` on `himss`, created by the build Action if missing | `himss-1.9.15` |
| Resource bundle | `app.resourceBundleVersion` (bumped by the process Action) | `1.9.15` |
| In the image | OCI label `org.opencontainers.image.version` and `/opt/himss-release` | `tool=1.9.15` |

To cut a new tool release: bump `app.version` (and `app.date`) on `himss-deploy`, PR into `himss`, merge. The build Action tags the image and the repo.

| Image tag | Meaning |
|-----------|---------|
| `himss-<app.version>` | Release tag (same as the git tag) |
| `<app.version>` | Short alias (`1.9.15`) |
| `rb-<app.resourceBundleVersion>` | Bundle version in this image |
| `sha-<7-char>` | Exact `himss` commit that was built |
| `himss` | Moving pointer at the last published `himss` image |
| `latest` | Same as this publish |

---

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| 404 on first start | Seeding still running; container logs |
| Empty test tree | App schemas were not empty on first boot, or the image predates the bundle |
| Wrong URL | Context path is `/immunization-himss/`, not `/iztool/` |
| Build cannot resolve deps | Valitheus Nexus reachable from the builder |

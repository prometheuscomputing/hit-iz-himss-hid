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

Two Actions. `himss-deploy` prepares and proves the image. `himss` publishes it.

```
push to himss-deploy
        │
        ├─ zip changed?  process + bump version + commit on himss-deploy
        └─ always         build + smoke  (no GHCR)

PR himss-deploy → himss     same build/smoke as a required check

merge into himss            publish GHCR
```

| Workflow | Trigger | Process zip | Build + smoke | GHCR |
|----------|---------|-------------|---------------|------|
| [himss-deploy.yml](.github/workflows/himss-deploy.yml) | Push to `himss-deploy` | Yes, if `tcamt-export/resources.zip` changed | Yes | No |
| [build-himss.yml](.github/workflows/build-himss.yml) | PR into `himss` | No | Yes | No |
| [publish-himss-image.yml](.github/workflows/publish-himss-image.yml) | Merge/push to `himss`, Release, or **Run workflow** | No | Yes | Yes |

### 1. Work on `himss-deploy`

Drop a TCAMT `exportRBZip` as `tcamt-export/resources.zip` and push. CI will organize `Contextbased/` + `Global/` (`iz`), generate PDFs, bump `app.resourceBundleVersion`, and commit that back to `himss-deploy`. Then it builds and smoke-tests the image.

You can still process on a workstation first if you want the diff in your own commit:

```bash
bash scripts/process-tcamt-resource-bundle.sh --apply --bump-version tcamt-export/resources.zip
```

If the zip did not change, CI skips processing and still builds when app or resource paths changed.

`Contextfree/`, `Documentation/`, `soap/`, and `About/` are not in the TCAMT zip. Do not randomize test object IDs on an update.

### 2. Pull request into `himss`

Open `himss-deploy` → `himss`. Reviewers see the processed resource diff. The PR check rebuilds and smoke-tests only — no publish.

### 3. Merge to `himss` — publish

`ghcr.io/prometheuscomputing/hit-iz-himss-hid`

| Tag | When |
|-----|------|
| `rb-<app.resourceBundleVersion>` | Merge to `himss` (e.g. `rb-1.9.15`) |
| `sha-<7-char>` | Merge to `himss` |
| `himss` | Moving pointer at latest merged `himss` |
| Release / manual tag + `latest` | GitHub Release or **Run workflow** |

---

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| 404 on first start | Seeding still running; container logs |
| Empty test tree | App schemas were not empty on first boot, or the image predates the bundle |
| Wrong URL | Context path is `/immunization-himss/`, not `/iztool/` |
| Build cannot resolve deps | Valitheus Nexus reachable from the builder |

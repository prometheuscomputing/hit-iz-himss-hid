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

Three Actions. Process and publish are opt-in. The image is built only on the PR into `himss`.

```
push zip to himss-deploy    process + bump version + commit  (no image)

PR himss-deploy → himss     build + smoke  (no GHCR)

merge into himss            nothing published

Release or Run workflow     build + smoke + publish GHCR
```

| Workflow | Trigger | Process zip | Build + smoke | GHCR |
|----------|---------|-------------|---------------|------|
| [process-resource-bundle.yml](.github/workflows/process-resource-bundle.yml) | Push of the TCAMT zip (or process scripts) to `himss-deploy`, or **Run workflow** | Yes, if `tcamt-export/resources.zip` changed | No | No |
| [build-himss.yml](.github/workflows/build-himss.yml) | PR into `himss` | No | Yes | No |
| [publish-himss-image.yml](.github/workflows/publish-himss-image.yml) | GitHub Release or **Run workflow** | No | Yes | Yes |

### 1. Process the zip on `himss-deploy`

Drop a TCAMT `exportRBZip` as `tcamt-export/resources.zip` and push. The process Action organizes `Contextbased/` + `Global/` (`iz`), generates PDFs, bumps `app.resourceBundleVersion`, and commits that back to `himss-deploy`. It does not build the image.

You can still process on a workstation first if you want the diff in your own commit:

```bash
bash scripts/process-tcamt-resource-bundle.sh --apply --bump-version tcamt-export/resources.zip
```

If the zip did not change, the process Action does nothing. A bot commit does not re-run the Action.

`Contextfree/`, `Documentation/`, `soap/`, and `About/` are not in the TCAMT zip. Do not randomize test object IDs on an update.

### 2. Pull request into `himss`

Open `himss-deploy` → `himss`. Reviewers see the processed resource diff. The PR check is the only automatic image build and smoke test. Merge does not publish.

### 3. Publish when you choose

`ghcr.io/prometheuscomputing/hit-iz-himss-hid`

Create a GitHub Release, or **Actions → Publish HIMSS Tool image → Run workflow** with a tag (for example `1.9.15`). That builds, smoke-tests, and pushes:

| Tag | Meaning |
|-----|---------|
| the Release / dispatch tag | What you named this publish |
| same tag without a leading `v` | Convenience alias |
| `rb-<app.resourceBundleVersion>` | Bundle version in `app-config.properties` (e.g. `rb-1.9.15`) |
| `sha-<7-char>` | Git SHA that was built |
| `himss` | Moving pointer at the last published image |
| `latest` | Same as this publish |

---

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| 404 on first start | Seeding still running; container logs |
| Empty test tree | App schemas were not empty on first boot, or the image predates the bundle |
| Wrong URL | Context path is `/immunization-himss/`, not `/iztool/` |
| Build cannot resolve deps | Valitheus Nexus reachable from the builder |

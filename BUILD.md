# Building the HIMSS Immunization Test Suite image

Branch: **`himss`**

This repo **only builds the Docker image**. It does not modify `Certification-Infra/cert-tools-local/himss`.

The cert-tools stack expects:

| Setting | Value |
|---------|-------|
| Image | `hit-iz-himss-hid:local` |
| URL | http://localhost:18085/immunization-himss/ |

Dependencies resolve from [Valitheus Nexus](https://nexus.valitheus.com/). Host only needs Docker.

**Branding:** see [BRANDING.md](BRANDING.md) for where to change HIMSS / SITT / Valitheus / Prometheus chrome and API-driven titles.

---

## Build the image

```bash
git checkout himss

# Full build (frontend + backend)
./build.sh

# Resource/backend-only (faster)
SKIP_FRONTEND=1 ./build.sh -s
```

Output: `hit-iz-himss-hid:local`

---

## Run with your existing cert-tools stack

Do **not** change anything under `cert-tools-local/himss`. After building:

```bash
cd /path/to/Certification-Infra/cert-tools-local/himss
docker compose up -d --force-recreate tool
```

Or from this repo in one step:

```bash
CERT_TOOLS_DIR=/path/to/Certification-Infra/cert-tools-local/himss ./build.sh -r
```

First boot takes ~45 s while the tool seeds empty MySQL schemas.

---

## Verify

```bash
curl -s "http://localhost:18085/immunization-himss/api/domains"
```

Should return JSON with the Immunization domain.

---

## What gets built

`docker/Dockerfile` multi-stage:

| Stage | Output |
|-------|--------|
| frontend | Node 8 + Grunt (node-sass) → webapp assets |
| backend | Maven → `immunization-himss.war` |
| runtime | Tomcat 9 + entrypoint (`DB_*` env → JNDI) |

---

## Export for offline bundle (optional)

```bash
docker save hit-iz-himss-hid:local | gzip > himss-image.tar.gz
```

Drop the tarball into `cert-tools-local/himss/` and `docker load -i himss-image.tar.gz` — no compose or init changes needed.

---

## Update test content from TCAMT

1. Export **HIMSS Immunization Integration Program CDC Modular Test Plan v11.0** from TCAMT (`exportRBZip`).
2. Copy the zip to `tcamt-export/resources.zip`.
3. Run:

```bash
bash scripts/publish-tcamt-resource-bundle.sh
git push origin himss
```

Pushing the updated zip (or running publish locally then pushing) triggers CI:

- **sync-tcamt-resource-bundle.yml** — process zip, generate PDFs, merge `hit-iz-resource/`, bump version
- **build-himss.yml** — build and smoke-test the image

See `tcamt-export/README.md` for details.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| 404 on first start | Wait for seeding; `docker compose logs -f tool` in cert-tools folder |
| Wrong URL | Use `/immunization-himss/` not `/iztool/` |
| Empty test cases | `docker compose down -v` in cert-tools folder, then start again |
| Build fails on deps | Ensure Valitheus Nexus is reachable |

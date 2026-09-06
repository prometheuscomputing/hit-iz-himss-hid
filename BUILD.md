# Building the HIMSS image

How the Docker image is produced. Releases use git tag `himss-<app.version>` (see [README.md](README.md)). The published image carries that version as `org.opencontainers.image.version` and `/opt/himss-release`.

The image is `hit-iz-himss-hid:local` when built on a workstation, or `ghcr.io/prometheuscomputing/hit-iz-himss-hid:<tag>` from CI. The app is always served at **`/immunization-himss/`**.

Dependencies resolve from [Valitheus Nexus](https://nexus.valitheus.com/). The builder needs Docker (and Nexus reachability). Branding: [BRANDING.md](BRANDING.md).

---

## Build

```bash
./build.sh                 # frontend + backend
SKIP_FRONTEND=1 ./build.sh -s
```

`./build.sh -r` rebuilds, then recreates the `tool` service in the compose directory given by `CERT_TOOLS_DIR` (your mapping — this repo does not assume a path).

---

## Image stages

`docker/Dockerfile` is multi-stage:

| Stage | Output |
|-------|--------|
| frontend | Node 8 + Grunt → webapp assets |
| backend | Maven → `immunization-himss.war` |
| runtime | Tomcat 9 + entrypoint (`DB_*` → JNDI) |

---

## Export a tarball (optional)

```bash
docker save hit-iz-himss-hid:local | gzip > himss-image.tar.gz
docker load -i himss-image.tar.gz
```

---

## Resource bundle

Process a TCAMT `exportRBZip` into `hit-iz-resource/` and bump `app.resourceBundleVersion` before opening a PR. Details: [README.md](README.md) and [tcamt-export/README.md](tcamt-export/README.md).

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Empty test cases after replace | Recreate the app DB volume so seed runs again |
| Wrong URL | `/immunization-himss/`, not `/iztool/` |
| Build fails on deps | Valitheus Nexus reachable from the builder |

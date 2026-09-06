# TCAMT resource bundle export

Put the TCAMT **exportRBZip** output in this directory as `resources.zip`. Any machine; no fixed download path.

How that zip becomes a reviewed PR and then a published image: [README.md](README.md) (Resource bundle and image).

## Process locally

```bash
# preview
bash scripts/process-tcamt-resource-bundle.sh tcamt-export/resources.zip

# write into hit-iz-resource/ and bump app.resourceBundleVersion
bash scripts/process-tcamt-resource-bundle.sh --apply --bump-version tcamt-export/resources.zip
```

Commit helper (processes, stages, commits — you push the branch):

```bash
bash scripts/publish-tcamt-resource-bundle.sh tcamt-export/resources.zip
```

## What the zip does and does not contain

- Updated: `Contextbased/` and `Global/` for domain `iz`.
- Unchanged in git: `Contextfree/`, `Documentation/`, `soap/`, `About/`.
- Do **not** run ID randomization on an update — that breaks stable test object IDs.

PDF generation uses `wkhtmltopdf` on the PATH, or Docker (`surnet/alpine-wkhtmltopdf`) if the binary is missing.

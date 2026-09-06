# TCAMT resource bundle export (source input)

Place the TCAMT **exportRBZip** output here as `resources.zip`.

When this file changes on branch `himss`, GitHub Actions will:

1. Organize `Contextbased/` and `Global/` under domain `iz`
2. Generate PDFs from `*PDF.html` via wkhtmltopdf
3. Merge into `hit-iz-resource/src/main/resources/`
4. Bump `app.resourceBundleVersion`
5. Commit the processed resources and trigger the HIMSS build workflow

## Local workflow

```bash
# 1. Export from TCAMT (plan 65bbb6102d8670360bc30cd8) and copy zip here
cp ~/Downloads/resources.zip tcamt-export/resources.zip

# 2. Process, bump version, commit
bash scripts/publish-tcamt-resource-bundle.sh

# 3. Push — CI builds and smoke-tests the image
git push origin himss
```

## Process only (no commit)

```bash
bash scripts/process-tcamt-resource-bundle.sh --apply --bump-version tcamt-export/resources.zip
```

Dry run first:

```bash
bash scripts/process-tcamt-resource-bundle.sh tcamt-export/resources.zip
```

## Notes

- `Contextfree/`, `Documentation/`, `soap/`, and `About/` are **not** in the TCAMT zip; they stay in the repo unchanged.
- Do **not** run `randomize_ids.py` on updates — it would break stable test object IDs.
- PDF generation uses local `wkhtmltopdf` or Docker (`surnet/alpine-wkhtmltopdf`) on macOS.

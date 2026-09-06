# Branding guide — HIMSS Immunization Integration Test Suite

This document explains **where each piece of branding lives**, how it reaches the deployed UI, and what to edit when you need to change names, logos, or partner chrome.

## Golden rule

**Edit the Grunt source under `hit-iz-web/client/`, then rebuild.**  
Do not hand-edit files under `hit-iz-web/src/main/webapp/` — that directory is **build output** (except when using `SKIP_FRONTEND=1` for backend-only builds).

```bash
./build.sh              # full Grunt + Maven; regenerates webapp/
SKIP_FRONTEND=1 ./build.sh -s   # skips Grunt; uses committed webapp as-is
```

After a full build, commit any updated `webapp/` files if you want skip-frontend builds to pick up the same branding.

---

## What you see in the browser

| UI element | Example (HIMSS deployment) | Source |
|------------|---------------------------|--------|
| Suite title + version | **HIMSS** Immunization Integration Test Suite **1.9.14** | Backend config → `/api/appInfo` |
| Subtitle | powered by NIST | Backend config → `app.domain` |
| SITT program line | Standards & Interoperability Testing Tools (SITT) | Frontend template + CSS |
| Header lockup | Hosted by **VALITHEUS** | Frontend template + CSS |
| Footer org logos | NIST / ITL (when configured) | Backend config → `appInfo.options` |
| Footer attribution | Previously known as the NIST tools | Frontend template |
| Footer lockup | Managed by **Prometheus Computing** | Frontend template + CSS |
| Email subject / tool name | HIMSS Immunization Integration Test Suite | Backend config |

---

## Frontend (Grunt source)

All partner chrome HTML and CSS lives in **`hit-iz-web/client/`**. Grunt compiles this into `hit-iz-web/src/main/webapp/` and Maven packages it into the WAR.

### Header — Valitheus + SITT

**File:** `hit-iz-web/client/app/views/header.html`

| Block | What to change |
|-------|----------------|
| `.hosted-lockup` | Valitheus link (`href`), eyebrow text ("Hosted by"), SVG mark, wordmark |
| `#programbrand .pb-text` | SITT program name |
| `#apptitle` / `#appsubtitle` | Bound to `appInfo` from the API (see backend section) |

The suite title line uses Angular bindings:

- `appInfo.options.ORGANIZATION_NAME` → e.g. **HIMSS**
- `appInfo.name` → e.g. Immunization Integration Test Suite
- `appInfo.version` → e.g. 1.9.14
- `appInfo.subTitle` → e.g. powered by NIST

### Footer — Prometheus + logos

**File:** `hit-iz-web/client/app/views/footer.html`

| Block | What to change |
|-------|----------------|
| `.footerImage` columns | Driven by `appInfo.options.ORGANIZATION_*` and `DIVISION_*` from API |
| `.prev-nist` | "Previously known as the NIST tools" attribution text |
| `.managed-by` | Prometheus link, eyebrow ("Managed by"), wordmark |

### Styles — partner chrome

**File:** `hit-iz-web/client/app/styles/branding.css`

Contains all CSS for:

- `#programbrand` (SITT line + tick)
- `.hosted-lockup` / `.appheader-mb` (Valitheus header)
- `.managed-by` (Prometheus footer + attribution layout)
- Shared `.mb` lockup primitives (eyebrow, mark, name)

This file is listed in the Grunt **usemin** CSS block in `client/app/index.html` (alongside `main.css`) so it is concatenated into the revved `styles/<hash>.main.css` bundle. **Do not** rely on `@import` from `main.scss` — Sass emits a runtime `@import` that does not survive the revved bundle path.

```html
<!-- build:css(.tmp) styles/main.css -->
<link rel="stylesheet" href="styles/main.css">
<link rel="stylesheet" href="styles/branding.css">
<!-- endbuild -->
```

### Page shell

**File:** `hit-iz-web/client/app/index.html`

Includes `views/header.html` and `views/footer.html` via `ng-include`. You normally do not need to edit this for branding changes.

---

## Backend (API-driven text)

**File:** `hit-iz-web/src/main/resources/app-config.properties`

These properties feed `/api/appInfo` and control text that appears in templates via Angular:

| Property | UI effect |
|----------|-----------|
| `app.organization.name` | Prefix before suite name in header (`ORGANIZATION_NAME`) |
| `app.name` | Suite name |
| `app.version` | Version badge (red) |
| `app.header` | Used in emails and some server-side labels |
| `app.domain` | Subtitle (`subTitle` in API) — e.g. `powered by NIST` |
| `app.date` | Footer "Application Information" date |
| `app.contactEmail` | Footer "Website Administrator" mailto |
| `app.organization.logo` / `app.organization.link` | Footer org logo column (`NA` hides it) |
| `app.division.logo` / `app.division.link` | Footer division logo column |
| `mail.subject` / `mail.tool` | Outbound email branding |

Registration, disclaimer, acknowledgment, and confidentiality HTML blocks are also in this file.

---

## Build pipeline

```
client/app/views/header.html  ─┐
client/app/views/footer.html  ─┼─► Grunt (Node 8 + Compass) ─► src/main/webapp/
client/app/styles/branding.css─┤         │
client/app/styles/main.scss   ─┘         ▼
                              Maven ─► immunization-himss.war ─► Docker image
```

Docker frontend stage requirements:

- **node-sass** + **grunt-sass** — compiles `main.scss` inside Node 8 (replaces legacy Ruby Compass)
- Grunt **must not** use `--force`; a missing `main.css` fails the build

The Dockerfile verifies:

1. `index.html` does **not** reference unrevved `styles/main.css`
2. A revved `styles/*main.css` file exists

---

## Common tasks

### Change the SITT program line

1. Edit `#programbrand .pb-text` in `client/app/views/header.html`
2. Optionally tune colors/spacing in `client/app/styles/branding.css` (`#programbrand`)
3. Run `./build.sh`

### Change Valitheus or Prometheus links/wordmarks

1. Edit the relevant block in `header.html` or `footer.html`
2. Adjust styles in `branding.css` if layout/colors change
3. Run `./build.sh`

### Change HIMSS title, version, or "powered by NIST"

1. Edit `app-config.properties` (no frontend rebuild strictly required for API-only text, but rebuild to keep WAR consistent)
2. Restart the tool container

### Backend-only change (no UI/HTML/CSS)

```bash
SKIP_FRONTEND=1 ./build.sh -s
```

---

## Verification checklist

After `./build.sh`:

```bash
# API branding
curl -s http://localhost:18085/immunization-himss/api/appInfo | jq '{organization, name, version, subTitle: .subTitle}'

# No broken CSS reference
curl -s http://localhost:18085/immunization-himss/index.html | grep main.css
# Should show styles/<hash>.main.css, NOT styles/main.css

# Header/footer templates present
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:18085/immunization-himss/views/header.html
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:18085/immunization-himss/views/footer.html
```

In the browser at `http://localhost:18085/immunization-himss/#/home` confirm:

- [ ] SITT line under the header (teal `#9fe4d8`)
- [ ] Valitheus lockup top-right (SVG mark renders — not a broken empty box)
- [ ] HIMSS title + version from API
- [ ] **No** “powered by NIST” subtitle (Valitheus prod leaves `subTitle` empty)
- [ ] **No** NIST/ITL footer logo columns (`ORGANIZATION_LOGO` / `DIVISION_LOGO` = `NA`)
- [ ] Prometheus footer lockup + “Previously known as the NIST tools”

### Match Valitheus prod (`tools.valitheus.com/immunization-himss`)

Prod ships these **exact** frontend assets (byte-identical to the cert-tools tarball):

| Asset | Hash / name |
|-------|-------------|
| Main CSS (includes partner chrome) | `styles/11649052.main.css` |
| Vendor JS (includes `LocalForageModule`) | `scripts/770cbab5.vendor.js` |
| Header / footer templates | Valitheus SVG + SITT + Prometheus blocks |

Local must **not** use the Grunt-rebuilt `67793306.main.css` / `5ba0c6ba.vendor.js` pair unless a full frontend build is verified to produce equivalent output.

**API / DB (subtitle & footer logos):** Valitheus prod stores empty `subTitle` and `ORGANIZATION_LOGO=NA` in MySQL, not in `app-config.properties` alone. After first boot, align the running DB:

```sql
UPDATE AppInfo SET subTitle='', contactEmail='', mailFrom='noreply@valitheus.local',
  url='https://tools.valitheus.com/immunization-himss' WHERE id=63;
UPDATE APP_OPTIONS SET OPTION_VALUE='NA'
  WHERE AppInfo_id=63 AND OPTION_TYPE IN ('ORGANIZATION_LOGO','ORGANIZATION_LINK','DIVISION_LINK','DIVISION_LOGO');
```

**Grunt note:** `htmlmin` must skip `views/header.html` and `views/footer.html` — minification lowercases SVG attributes (`viewBox` → `viewbox`) and breaks the Valitheus mark.

---

## Files **not** to edit for branding

| Path | Why |
|------|-----|
| `webapp/styles/*.main.css` | Generated; branding comes from `client/app/styles/branding.css` |
| `webapp/views/header.html` / `footer.html` | Generated from `client/app/views/` on full build |
| Prod tarball / cert-tools compose | Runtime infra only; image is built from this repo |

---

## Related docs

- [BUILD.md](BUILD.md) — Docker/Maven build and deploy
- `docker/Dockerfile` — multi-stage build (frontend → backend → Tomcat)

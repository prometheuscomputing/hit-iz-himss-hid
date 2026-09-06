#!/usr/bin/env bash
# Process a TCAMT exportRBZip into hit-iz-resource (organize, PDFs, merge).
#
# Usage:
#   bash scripts/process-tcamt-resource-bundle.sh [options] <export.zip>
#
# Options:
#   --domain NAME           Resource domain folder (default: iz)
#   --target-plan-dir NAME  Override plan folder rename (see scripts/rb/plan-folder.map)
#   --apply                 Write into hit-iz-resource (default is dry-run)
#   --bump-version          Increment app.resourceBundleVersion patch (requires --apply)
#   --skip-pdf              Skip wkhtmltopdf step (HTML intermediates remain)
#   -h, --help              Show help
#
# Typical local flow:
#   cp ~/Downloads/resources.zip tcamt-export/resources.zip
#   bash scripts/process-tcamt-resource-bundle.sh --apply --bump-version tcamt-export/resources.zip
#   git add hit-iz-resource hit-iz-web/src/main/resources/app-config.properties tcamt-export/resources.zip
#   git commit -m "chore: sync resource bundle from TCAMT export"
#   git push origin himss

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RB_DIR="${ROOT_DIR}/scripts/rb"
RESOURCE_ROOT="${ROOT_DIR}/hit-iz-resource/src/main/resources"
APP_CONFIG="${ROOT_DIR}/hit-iz-web/src/main/resources/app-config.properties"
PLAN_MAP="${RB_DIR}/plan-folder.map"

DOMAIN="iz"
TARGET_PLAN_DIR=""
APPLY=0
BUMP_VERSION=0
SKIP_PDF=0
ZIP_PATH=""

usage() {
    sed -n '2,22p' "$0"
}

log() {
    echo "==> $*"
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

resolve_plan_target_name() {
    local source_name="$1"
    local resolved="$TARGET_PLAN_DIR"

    if [ -z "$resolved" ] && [ -f "$PLAN_MAP" ]; then
        while IFS='=' read -r src dst; do
            [ -z "$src" ] && continue
            [[ "$src" =~ ^# ]] && continue
            if [ "$src" = "$source_name" ]; then
                resolved="$dst"
                break
            fi
        done < "$PLAN_MAP"
    fi

    if [ -z "$resolved" ]; then
        resolved="${source_name// /_}"
        resolved="${resolved//./_}"
        resolved="${resolved/_v11_0/_v11}"
    fi

    printf '%s' "$resolved"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --domain)
            DOMAIN="${2:?missing value for --domain}"
            shift 2
            ;;
        --target-plan-dir)
            TARGET_PLAN_DIR="${2:?missing value for --target-plan-dir}"
            shift 2
            ;;
        --apply)
            APPLY=1
            shift
            ;;
        --bump-version)
            BUMP_VERSION=1
            shift
            ;;
        --skip-pdf)
            SKIP_PDF=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            die "Unknown option: $1"
            ;;
        *)
            if [ -n "$ZIP_PATH" ]; then
                die "Unexpected argument: $1"
            fi
            ZIP_PATH="$1"
            shift
            ;;
    esac
done

[ -n "$ZIP_PATH" ] || die "Missing export.zip path"
[ -f "$ZIP_PATH" ] || die "Zip not found: $ZIP_PATH"
[ "$BUMP_VERSION" -eq 0 ] || [ "$APPLY" -eq 1 ] || die "--bump-version requires --apply"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tcamt-rb-XXXXXX")"
STAGING="${WORK_DIR}/staging"
EXTRACT="${WORK_DIR}/extract"
trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$STAGING" "$EXTRACT"
log "Extracting $(basename "$ZIP_PATH")"
unzip -q "$ZIP_PATH" -d "$EXTRACT"

[ -d "$EXTRACT/Contextbased" ] && [ -d "$EXTRACT/Global" ] || die "Zip must contain Contextbased/ and Global/ at top level"

log "Organizing for domain '$DOMAIN'"
bash "${RB_DIR}/organize_rb.sh" "$DOMAIN" "$EXTRACT"

CONTEXT_DOMAIN="${EXTRACT}/Contextbased/${DOMAIN}"
GLOBAL_ROOT="${EXTRACT}/Global"
[ -d "$CONTEXT_DOMAIN" ] || die "No Contextbased/${DOMAIN} after organize"

PLAN_DIRS=()
while IFS= read -r plan_dir; do
    PLAN_DIRS+=("$plan_dir")
done < <(find "$CONTEXT_DOMAIN" -mindepth 1 -maxdepth 1 -type d | sort)
[ "${#PLAN_DIRS[@]}" -ge 1 ] || die "No test plans found under Contextbased/${DOMAIN}"

declare -a STAGED_PLAN_TARGETS=()
declare -a FINAL_PLAN_DIRS=()

for plan_dir in "${PLAN_DIRS[@]}"; do
    source_plan_name="$(basename "$plan_dir")"
    resolved_target="$(resolve_plan_target_name "$source_plan_name")"
    final_plan_dir="${CONTEXT_DOMAIN}/${resolved_target}"

    if [ "$source_plan_name" != "$resolved_target" ]; then
        log "Renaming plan folder: '$source_plan_name' -> '$resolved_target'"
        mv "${CONTEXT_DOMAIN}/${source_plan_name}" "$final_plan_dir"
    fi

    FINAL_PLAN_DIRS+=("$final_plan_dir")
    STAGED_PLAN_TARGETS+=("$resolved_target")

    if [ "$SKIP_PDF" -eq 0 ] && [ "$APPLY" -eq 0 ]; then
        log "Skipping PDF generation in dry-run (use --apply to generate PDFs)"
        SKIP_PDF=1
    fi

    if [ "$SKIP_PDF" -eq 0 ]; then
        log "Generating PDFs for '${resolved_target}' (wkhtmltopdf)"
        chmod +x "${RB_DIR}/run-wkhtmltopdf.sh"
        export WKHTML_WORK_ROOT="$EXTRACT"
        export WKHTMLTOPDF="${RB_DIR}/run-wkhtmltopdf.sh"
        if ! command -v wkhtmltopdf >/dev/null 2>&1; then
            export WKHTML_USE_DOCKER=1
        fi
        python3 "${RB_DIR}/pdf_generator.py" "$final_plan_dir"
    else
        log "Skipping PDF generation (--skip-pdf or dry-run)"
    fi
done

PLAN_DIRS=("${FINAL_PLAN_DIRS[@]}")

log "Staging merge tree"
mkdir -p "${STAGING}/Contextbased/${DOMAIN}"
for plan_dir in "${PLAN_DIRS[@]}"; do
    resolved_target="$(basename "$plan_dir")"
    rsync -a "${plan_dir}/" "${STAGING}/Contextbased/${DOMAIN}/${resolved_target}/"
done

for category in "$GLOBAL_ROOT"/*; do
    [ -d "$category" ] || continue
    src="${category}/${DOMAIN}"
    [ -d "$src" ] || continue
    cat_name="$(basename "$category")"
    mkdir -p "${STAGING}/Global/${cat_name}/${DOMAIN}"
    rsync -a "${src}/" "${STAGING}/Global/${cat_name}/${DOMAIN}/"
done

PDF_COUNT="$(find "${STAGING}/Contextbased/${DOMAIN}" -name '*.pdf' | wc -l | tr -d ' ')"
HTML_PDF_COUNT="$(find "${STAGING}/Contextbased/${DOMAIN}" -name '*PDF.html' | wc -l | tr -d ' ')"
log "Staged ${PDF_COUNT} PDF(s), ${HTML_PDF_COUNT} *PDF.html remaining under Contextbased/${DOMAIN}"

if [ "$APPLY" -eq 1 ] && [ "$SKIP_PDF" -eq 0 ] && [ "$HTML_PDF_COUNT" -ne 0 ]; then
    die "PDF generation incomplete: ${HTML_PDF_COUNT} *PDF.html file(s) still present"
fi

if [ "$APPLY" -eq 1 ] && [ "$SKIP_PDF" -eq 0 ] && [ "$PDF_COUNT" -eq 0 ]; then
    die "PDF generation produced no PDFs under Contextbased/${DOMAIN}"
fi

verify_root_plan_pdfs() {
    local plan_root="$1"
    local plan_name="$2"
    local missing=0
    for pdf_name in TestPlanSummary.pdf TestPackage.pdf TestStory.pdf; do
        local pdf_path="${plan_root}/${pdf_name}"
        if [ ! -f "$pdf_path" ]; then
            echo "ERROR: Missing root PDF ${pdf_name} for plan '${plan_name}'" >&2
            missing=1
            continue
        fi
        local size
        size="$(wc -c < "$pdf_path" | tr -d ' ')"
        if [ "$pdf_name" != "TestStory.pdf" ] && [ "$size" -lt 10000 ]; then
            echo "ERROR: Root PDF ${pdf_name} for plan '${plan_name}' is too small (${size} bytes)" >&2
            missing=1
        fi
    done
    [ "$missing" -eq 0 ] || die "Root plan PDF verification failed for '${plan_name}'"
}

if [ "$APPLY" -eq 1 ] && [ "$SKIP_PDF" -eq 0 ]; then
    for plan_dir in "${PLAN_DIRS[@]}"; do
        verify_root_plan_pdfs "$plan_dir" "$(basename "$plan_dir")"
    done
fi

CONTEXT_DEST="${RESOURCE_ROOT}/Contextbased/${DOMAIN}"

if [ "$APPLY" -eq 0 ]; then
    echo
    echo "Dry run — no files written. Would replace:"
    echo "  ${CONTEXT_DEST}/ (remove all existing plans, copy ${#STAGED_PLAN_TARGETS[@]} from export)"
    for target in "${STAGED_PLAN_TARGETS[@]}"; do
        echo "    - ${target}/"
    done
    for category in "$GLOBAL_ROOT"/*; do
        [ -d "${category}/${DOMAIN}" ] || continue
        echo "  ${RESOURCE_ROOT}/Global/$(basename "$category")/${DOMAIN}/ (remove existing, copy from export)"
    done
    if [ "$BUMP_VERSION" -eq 1 ]; then
        echo "  ${APP_CONFIG} (resourceBundleVersion patch bump)"
    fi
    echo
    echo "Re-run with --apply to write changes."
    exit 0
fi

log "Replacing ${CONTEXT_DEST}/ from TCAMT export (${#STAGED_PLAN_TARGETS[@]} plan(s))"
rm -rf "$CONTEXT_DEST"
mkdir -p "$CONTEXT_DEST"
for target in "${STAGED_PLAN_TARGETS[@]}"; do
    rsync -a "${STAGING}/Contextbased/${DOMAIN}/${target}/" "${CONTEXT_DEST}/${target}/"
done

for category in "${STAGING}/Global"/*; do
    [ -d "$category" ] || continue
    src="${category}/${DOMAIN}"
    [ -d "$src" ] || continue
    cat_name="$(basename "$category")"
    dest="${RESOURCE_ROOT}/Global/${cat_name}/${DOMAIN}"
    log "Replacing ${dest}/ from TCAMT export"
    rm -rf "$dest"
    mkdir -p "$dest"
    rsync -a "${src}/" "${dest}/"
done

if [ "$BUMP_VERSION" -eq 1 ]; then
    current="$(grep '^app.resourceBundleVersion=' "$APP_CONFIG" | cut -d= -f2)"
    if [[ ! "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        die "Cannot parse app.resourceBundleVersion=$current"
    fi
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"
    next_patch=$((patch + 1))
    new_version="${major}.${minor}.${next_patch}"
    log "Bumping app.resourceBundleVersion: ${current} -> ${new_version}"
    if [[ "$(uname)" == Darwin* ]]; then
        sed -i '' "s/^app.resourceBundleVersion=.*/app.resourceBundleVersion=${new_version}/" "$APP_CONFIG"
    else
        sed -i "s/^app.resourceBundleVersion=.*/app.resourceBundleVersion=${new_version}/" "$APP_CONFIG"
    fi
fi

APPLIED_PDF_COUNT="$(find "$CONTEXT_DEST" -name '*.pdf' | wc -l | tr -d ' ')"
APPLIED_HTML_PDF_COUNT="$(find "$CONTEXT_DEST" -name '*PDF.html' | wc -l | tr -d ' ')"
log "Applied ${APPLIED_PDF_COUNT} PDF(s); ${APPLIED_HTML_PDF_COUNT} *PDF.html remaining"
log "Done. Updated Contextbased/${DOMAIN}: ${STAGED_PLAN_TARGETS[*]}"
echo "Next: commit hit-iz-resource (+ app-config if bumped) and push to trigger CI."

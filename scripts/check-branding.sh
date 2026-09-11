#!/usr/bin/env bash
# Branding gate on the content a fresh schema seeds from: the About pages and
# document lists in the resource bundle, the tool identity in app-config, the
# language bundle. The 1.9.15 rollout came up on a fresh schema and re-seeded
# the old home page text, which a partner tester found before we did. This
# refuses to build an image that would do it again.
#
# Fails on any NIST / nist.gov mention outside the approved sentences below
# (the About and legal text keeps the origin attribution, the funding history
# and the public-domain notice on purpose). Run it on its own with
#   bash scripts/check-branding.sh
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
import glob, html, json, os, re, sys

allowed = [
    "National Institute of Standards and Technology (NIST), an agency of the United States Federal Government",
    "originally developed by employees and contractors of the National Institute of Standards and Technology (NIST)",
    "works created by NIST employees within the scope of their employment",
    "to the extent that NIST,",
    "endorsement by NIST,",
    "by NIST, CDC, ONC, AIRA, or Prometheus Computing, LLC",
    "NIST, CDC, ONC, AIRA, and Prometheus Computing, LLC appreciate",
    "IN NO EVENT SHALL NIST,",
    "CDC, ONC, AIRA, NIST, and any stakeholder",
    "CDC, ONC, AIRA, NIST, or any stakeholder",
    "NIST Acknowledgement",
    "National Institute of Standards and Technology (NIST) in collaboration with",
    "National Institute of Standards and Technology (NIST), is no longer funding the project",
    "The former \"NIST Tools\" have been rebranded",
    "Neither NIST nor Prometheus Computing, LLC assumes responsibility",
    "NIST Errata and Clarifications Guidelines",
    "NIST_IZ_Normative_Test_Process_Document",
    "NIST_IZ_Tool_SOAP_Tutorial",
    "NIST IZ Normative Test Process Document",
    "NIST IZ Tool SOAP Tutorial",
    # Titles and file names of NIST-authored documents still served under Documentation.
    "NIST Immunization Normative Test Process Document for ONC 2015 Certification",
    "NIST Clarifications and Validation Guidelines",
    "NIST-Clarifications-and-Validation-Guidelines",
    "NIST-IZ_QuickReferenceGuide",
    "NIST Immunization ATL Training",
    "NIST-IZ-Tool-ATL-Training",
    "Understanding NIST HL7 v2 Validation",
    "NIST-HL7v2-Understanding-Validation",
    "NIST Immunization Tool SOAP Tutorial",
    "Installation Guide - NIST HL7v2 Validation Tools",
]

# Downloads.json lists the old release zips, still hosted on NIST's server until the
# document mirror lands; it is the one file left out of this gate on purpose.
skipped = {"hit-iz-resource/src/main/resources/Documentation/Downloads/app/Downloads.json"}

# What ships: the resource bundle, the tool identity, the committed frontend. The
# frontend sources under client/app only ship when CI rebuilds them (Grunt), so
# they join the scan when the workflow says so.
files = (
    glob.glob("hit-iz-resource/src/main/resources/About/**/*.html", recursive=True)
    + glob.glob("hit-iz-resource/src/main/resources/Documentation/**/*.json", recursive=True)
    + ["hit-iz-web/src/main/resources/app-config.properties",
       "hit-iz-web/src/main/webapp/lang/messages_en.properties",
       "hit-iz-web/src/main/webapp/index.html"]
)
if os.environ.get("CHECK_FRONTEND_SOURCE") == "1":
    files += ["hit-iz-web/client/app/lang/messages_en.properties",
              "hit-iz-web/client/app/index.html"]
files = sorted(f for f in files if f not in skipped)

def scrub(text):
    for phrase in allowed:
        text = re.sub(r"\s+".join(re.escape(w) for w in phrase.split()), " ", text)
    return text

bad = 0
for f in files:
    raw = open(f, encoding="utf-8", errors="replace").read()
    if f.endswith(".json"):
        try:
            raw = "\n".join(str(v) for v in json.loads(raw) for v in (v.values() if isinstance(v, dict) else [v]))
        except ValueError:
            pass
    text = scrub(re.sub(r"<[^>]+>", " ", html.unescape(raw)))
    hits = [m for m in re.finditer(r"NIST|nist\.gov", text)]
    if not hits:
        continue
    bad += 1
    print("check-branding: %s: %d mention(s) outside the approved wording" % (f, len(hits)))
    for m in hits[:5]:
        lo, hi = max(0, m.start() - 60), min(len(text), m.end() + 60)
        print("    ... %s ..." % re.sub(r"\s+", " ", text[lo:hi]).strip())
if bad:
    print("check-branding: FAILED (%d file(s))" % bad)
    sys.exit(1)
print("check-branding: ok (%d files)" % len(files))
PY

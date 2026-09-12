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
    "As of August 2026, the National Institute of Standards and Technology (NIST), is no longer funding the project, and ongoing support for the tools is funded by the Centers for Disease Control and Prevention (CDC) and Office of the National Coordinator (ONC) for Health Information Technology, a component of the U.S.",
    "Favorable outcome in the use of the test materials on this site does not imply conformance recognition or endorsement by NIST, CDC, ONC, AIRA, or Prometheus Computing, LLC.",
    "IN NO EVENT SHALL NIST, CDC, ONC, AIRA, OR PROMETHEUS COMPUTING, LLC BE LIABLE FOR ANY DAMAGES, INCLUDING, BUT NOT LIMITED TO, DIRECT, INDIRECT, SPECIAL, OR CONSEQUENTIAL DAMAGES, ARISING OUT OF, RESULTING FROM, OR IN ANY WAY CONNECTED WITH THIS SOFTWARE, WHETHER OR NOT BASED UPON WARRANTY, CONTRACT, TORT, OR OTHERWISE, WHETHER OR NOT INJURY WAS SUSTAINED BY PERSONS OR PROPERTY OR OTHERWISE, AND WHETHER OR NOT LOSS WAS SUSTAINED FROM, OR AROSE OUT OF THE RESULTS OF, OR USE OF, THE SOFTWARE OR SERVICES PROVIDED HEREUNDER.",
    "Information provided in the tool does not imply endorsement of any particular product, service, organization, company, information provider, or content by NIST, CDC, ONC, AIRA, or Prometheus Computing, LLC.",
    "NIST, CDC, ONC, AIRA, and Prometheus Computing, LLC appreciate acknowledgment if the software is used.",
    "Neither NIST nor Prometheus Computing, LLC assumes responsibility for its use by other parties, and no guarantees, expressed or implied, are made about its quality, reliability, or any other characteristic.",
    "Permission in the United States and in foreign countries, to the extent that NIST, the CDC, ONC, AIRA, Prometheus Computing, LLC, or the U.S.",
    "Prometheus Computing LLC, CDC, ONC, AIRA, NIST, and any stakeholder responsible for, participating in, or having participated in sponsoring the program under which the tools are funded are not responsible for user-provided or organization-provided content that is uploaded, entered, shared, stored, or transmitted in violation of applicable law, regulation, policy, contract, privacy requirement, security requirement, data-use restriction, or organizational rule.",
    "Prometheus Computing LLC, CDC, ONC, AIRA, NIST, and any stakeholder responsible for, participating in, or having participated in sponsoring the program under which the tools are funded do not obtain ownership of that content and may not use it for any unrelated business, commercial, or organizational purpose outside the operation, support, maintenance, migration, security, and administration of the tools.",
    "Pursuant to Title 17, United States Code, Section 105, works created by NIST employees within the scope of their employment are not subject to copyright protection in the United States and reside in the public domain.",
    "Such access does not transfer ownership of user-provided or organization-provided content to Prometheus Computing LLC, CDC, ONC, AIRA, NIST, or any stakeholder responsible for, participating in, or having participated in sponsoring the program under which the tools are funded.",
    "The former \"NIST Tools\" have been rebranded as the Standards & Interoperability Testing Tools (SITT).",
    "This Test Suite, the test data, and associated artifacts were originally developed by the National Institute of Standards and Technology (NIST) in collaboration with the Centers for Disease Control and Prevention (CDC) and the American Immunization Registries Association (AIRA).",
    "This software was originally developed by employees and contractors of the National Institute of Standards and Technology (NIST), an agency of the United States Federal Government.",
    "This software was originally developed by employees and contractors of the National Institute of Standards and Technology (NIST).",
    "NIST Acknowledgement",
    "Previously known as the NIST tools",
    "NIST Errata and Clarifications Guidelines",
    "NIST_IZ_Normative_Test_Process_Document",
    "NIST_IZ_Tool_SOAP_Tutorial",
    "NIST IZ Normative Test Process Document",
    "NIST IZ Tool SOAP Tutorial",
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
       "hit-iz-web/src/main/webapp/index.html",
       "hit-iz-web/src/main/webapp/views/header.html",
       "hit-iz-web/src/main/webapp/views/footer.html",
       "hit-iz-web/src/main/webapp/views/home.html",
       "hit-iz-web/src/main/webapp/views/about.html"]
)
if os.environ.get("CHECK_FRONTEND_SOURCE") == "1":
    files += ["hit-iz-web/client/app/lang/messages_en.properties",
              "hit-iz-web/client/app/index.html",
              "hit-iz-web/client/app/views/header.html",
              "hit-iz-web/client/app/views/footer.html",
              "hit-iz-web/client/app/views/home.html",
              "hit-iz-web/client/app/views/about.html"]
files = sorted(f for f in files if f not in skipped)

# The allowlist holds whole approved sentences or whole document titles, never
# fragments: a fragment would also erase the start of an unapproved sentence.
for phrase in allowed:
    if phrase.rstrip().endswith((",", ";", "and", "or", "by", "that")):
        sys.exit("check-branding: allowlist entry is a fragment, not a sentence: %r" % phrase)

def scrub(text):
    for phrase in allowed:
        pattern = r"(?<![A-Za-z0-9])" + r"\s+".join(re.escape(w) for w in phrase.split()) + r"(?![A-Za-z0-9])"
        text = re.sub(pattern, " ", text)
    return text

# A tag is replaced by the attribute values a reader can see or follow (link
# targets, image sources, meta content, titles), whatever the case or spacing.
ATTR = re.compile(r'(?:href|src|content|title|alt)\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|([^\s>"\']+))', re.I)
def visible(m):
    return " " + " ".join("".join(g) for g in ATTR.findall(m.group(0))) + " "

bad = 0
for f in files:
    raw = open(f, encoding="utf-8", errors="replace").read()
    if f.endswith(".json"):
        try:
            raw = "\n".join(str(v) for v in json.loads(raw) for v in (v.values() if isinstance(v, dict) else [v]))
        except ValueError:
            pass
    text = scrub(re.sub(r"<[^>]+>", visible, html.unescape(raw)))
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

#!/usr/bin/env python3
"""Convert TCAMT *PDF.html intermediates to PDFs for the HIMSS resource bundle."""

import os
import shutil
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
WKHTML = os.environ.get("WKHTMLTOPDF", os.path.join(SCRIPT_DIR, "run-wkhtmltopdf.sh"))

ROOT_HTML_ARTIFACTS = (
    ("CoverPage.html", "cover"),
    ("TestPlanSummary.html", "simple"),
    ("TestPackage.html", "package"),
    ("TestStoryPDF.html", "pdf_html"),
)


def run_wkhtml(args):
    process = subprocess.Popen(
        [WKHTML, *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    for line in process.stdout:
        print(line.strip())
    if process.wait() != 0:
        raise RuntimeError(f"wkhtmltopdf failed: {' '.join(args)}")


def gen_pdf(html_filename, pdf_filename):
    run_wkhtml([html_filename, pdf_filename])


def gen_toc_pdf(html_filename, pdf_filename):
    run_wkhtml(["toc", html_filename, pdf_filename])


def gen_cover_page_pdf(html_filename, pdf_filename, coverpage_filename):
    run_wkhtml(["cover", coverpage_filename, "toc", html_filename, pdf_filename])


def pdf_html_to_pdf(html_filename):
    pdf_filename = html_filename.replace("PDF.html", ".pdf")
    gen_pdf(html_filename, pdf_filename)
    os.remove(html_filename)
    return pdf_filename


def generate_root_plan_pdfs(plan_dir):
    """Generate plan-root PDFs in a fixed order (cover, summary, package, test story)."""
    generated = []
    for html_name, kind in ROOT_HTML_ARTIFACTS:
        html_path = os.path.join(plan_dir, html_name)
        if not os.path.isfile(html_path):
            continue

        if kind == "pdf_html":
            pdf_path = pdf_html_to_pdf(html_path)
        elif kind == "cover":
            pdf_path = html_path.replace(".html", ".pdf")
            gen_pdf(html_path, pdf_path)
        elif kind == "simple":
            pdf_path = html_path.replace(".html", ".pdf")
            gen_pdf(html_path, pdf_path)
        elif kind == "package":
            pdf_path = html_path.replace(".html", ".pdf")
            coverpage_path = os.path.join(plan_dir, "CoverPage.html")
            if not os.path.isfile(coverpage_path):
                raise RuntimeError(f"Missing CoverPage.html for {html_path}")
            gen_cover_page_pdf(html_path, pdf_path, coverpage_path)
        else:
            raise RuntimeError(f"Unknown root artifact kind: {kind}")

        generated.append(pdf_path)
        print(f"Generated root PDF: {pdf_path}")

    # Fallback when TestStoryPDF.html was already consumed in a prior run.
    test_story_html = os.path.join(plan_dir, "TestStory.html")
    test_story_pdf = os.path.join(plan_dir, "TestStory.pdf")
    if os.path.isfile(test_story_html) and not os.path.isfile(test_story_pdf):
        gen_pdf(test_story_html, test_story_pdf)
        generated.append(test_story_pdf)
        print(f"Generated root PDF: {test_story_pdf}")

    return generated


def process_dir(source):
    generate_root_plan_pdfs(source)

    for root, _, files in os.walk(source):
        for file in files:
            if not file.endswith(".html"):
                continue
            filepath = os.path.join(root, file)
            if root == source and file in {name for name, _ in ROOT_HTML_ARTIFACTS}:
                continue
            if file == "TestStory.html":
                continue
            if file.endswith("PDF.html"):
                pdf_html_to_pdf(filepath)
            else:
                pdf_filename = filepath.replace(".html", ".pdf")
                gen_pdf(filepath, pdf_filename)


def main():
    if len(sys.argv) != 2:
        print("Usage: pdf_generator.py <test_plan_directory>", file=sys.stderr)
        sys.exit(1)

    test_plan_directory = sys.argv[1]
    if not os.path.isdir(test_plan_directory):
        print(f"Error: Directory '{test_plan_directory}' does not exist.", file=sys.stderr)
        sys.exit(1)

    if not os.path.isfile(WKHTML) and not shutil.which(WKHTML):
        print(f"Error: wkhtmltopdf wrapper not found at {WKHTML}", file=sys.stderr)
        sys.exit(127)

    process_dir(test_plan_directory)


if __name__ == "__main__":
    main()

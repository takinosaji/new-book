"""
Post-process a rendered Quarto docx to restore missing footer/header references
in intermediate section breaks.

When pandoc generates landscape sections via ::: {.landscape} divs it emits
minimal <w:sectPr> elements without inheriting the footer/header references
from the reference-doc, so those pages lose their page numbers. This script
copies the references from the body-level sectPr into every intermediate sectPr
that is missing them.

Usage:
    uv run sdlc/ci/build-scripts/fix_landscape_footer.py <path/to/book.docx>
"""
import copy
import shutil
import sys
import zipfile
from lxml import etree

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
REF_TAGS = {f"{{{W}}}footerReference", f"{{{W}}}headerReference"}


def fix(docx_path: str) -> None:
    with zipfile.ZipFile(docx_path) as z:
        with z.open("word/document.xml") as f:
            doc = etree.parse(f)

    root = doc.getroot()
    body = root.find(f"{{{W}}}body")
    body_sectPr = body.find(f"{{{W}}}sectPr")
    inherited = [el for el in body_sectPr if el.tag in REF_TAGS]

    if not inherited:
        print("No footer/header references found in body sectPr — nothing to do.")
        return

    fixed = 0
    for pPr in root.findall(f".//{{{W}}}pPr"):
        sectPr = pPr.find(f"{{{W}}}sectPr")
        if sectPr is None:
            continue
        existing = {el.tag for el in sectPr}
        for ref in inherited:
            if ref.tag not in existing:
                sectPr.append(copy.deepcopy(ref))
        fixed += 1

    print(f"Fixed {fixed} intermediate section(s) in {docx_path}")

    modified_xml = etree.tostring(
        root, xml_declaration=True, encoding="UTF-8", standalone=True
    )
    tmp = docx_path + ".tmp"
    with zipfile.ZipFile(docx_path) as zin, zipfile.ZipFile(
        tmp, "w", zipfile.ZIP_DEFLATED
    ) as zout:
        for item in zin.infolist():
            data = modified_xml if item.filename == "word/document.xml" else zin.read(item.filename)
            zout.writestr(item, data)
    shutil.move(tmp, docx_path)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <path/to/book.docx>")
        sys.exit(1)
    fix(sys.argv[1])

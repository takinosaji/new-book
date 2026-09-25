"""Render the book to docx, name it with the version, and restore landscape page numbers."""
import glob
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from book_config import read_output_file, read_version

src = "src"
book_dir = "_book"
base = read_output_file() or "book"
version = read_version()

subprocess.run(["quarto", "--version"], check=True)
subprocess.run(
    ["quarto", "render", "--to", "docx", "--log-level", "debug"],
    cwd=src,
    check=True,
)

built_path = os.path.join(book_dir, f"{base}.docx")
if not os.path.exists(built_path):
    candidates = glob.glob(os.path.join(book_dir, "*.docx"))
    if not candidates:
        raise FileNotFoundError(f"No .docx found in {book_dir}/")
    built_path = max(candidates, key=os.path.getmtime)

target = os.path.join(book_dir, f"{base}-{version}.docx" if version else f"{base}.docx")
if os.path.abspath(built_path) != os.path.abspath(target):
    os.replace(built_path, target)

subprocess.run(
    [sys.executable, "sdlc/ci/build-scripts/fix_landscape_footer.py", target],
    check=True,
)

"""Render the book to docx and post-process landscape sections to restore page numbers."""
import glob
import os
import subprocess
import sys

src = "src"
book_dir = "_book"

subprocess.run(["quarto", "render", "--to", "docx"], cwd=src, check=True)

docx_files = glob.glob(os.path.join(book_dir, "*.docx"))
if not docx_files:
    raise FileNotFoundError(f"No .docx found in {book_dir}/")

built_path = max(docx_files, key=os.path.getmtime)

subprocess.run(
    [sys.executable, "sdlc/ci/build-scripts/fix_landscape_footer.py", built_path],
    check=True,
)

import os
import shutil
import subprocess

src = "src"
book_cfg = os.path.join(src, "_quarto.yml")
website_cfg = os.path.join(src, "_quarto-website.yml")
backup_cfg = os.path.join(src, "_quarto-book.yml")

try:
    shutil.copy(book_cfg, backup_cfg)
    shutil.copy(website_cfg, book_cfg)
    subprocess.run(["quarto", "render"], cwd=src, check=True)
finally:
    if os.path.exists(backup_cfg):
        shutil.copy(backup_cfg, book_cfg)
        os.remove(backup_cfg)

import json, os, subprocess, sys

# Derive project root from this file's location (.claude/hooks/lint-hook.py → project root)
project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

data = json.load(sys.stdin)
f = data.get("tool_input", {}).get("file_path", "")

if f.endswith(".md"):
    subprocess.run(
        ["markdownlint-cli2", "--config", os.path.join(project_root, ".markdownlint-md.yml"), f],
        cwd=project_root,
        shell=(os.name == "nt"),
    )
elif f.endswith(".qmd"):
    subprocess.run(
        ["markdownlint-cli2", "--config", os.path.join(project_root, ".markdownlint-qmd.yml"), f],
        cwd=project_root,
        shell=(os.name == "nt"),
    )

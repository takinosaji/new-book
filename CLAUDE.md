# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Architecture documentation built with [Quarto](https://quarto.org/).
All source files are `.qmd` (Quarto Markdown). The repo produces two outputs:

- **Website** (`_site/`) — deployed to GitLab Pages via CI
- **Word document** (`_book/*.docx`) — generated from the book configuration

## Commands

```bash
# Live preview (website format)
cd src && quarto preview

# Build HTML website — safe local method (handles config swap, restores on error)
uv run sdlc/ci/build-scripts/render_website.py

# Build HTML website — manual method (restore src/_quarto.yml afterwards)
cp src/_quarto-website.yml src/_quarto.yml && (cd src && quarto render)

# Build Word document
cd src && quarto render --to docx

# Lint markdown
markdownlint-cli2 "**/*.md" --config .markdownlint-md.yml
markdownlint-cli2 "**/*.qmd" --config .markdownlint-qmd.yml
```

CI uses `markdownlint-cli2` (not `markdownlint-cli`). Both are compatible with the same config files.

**Always pass `--config` explicitly.** Without it, markdownlint-cli2 falls back to built-in defaults
(e.g. MD036 enabled, MD013 at 80 chars) which differ from the project rules and produce false errors.

## Automatic Linting

A Claude Code hook in `.claude/settings.json` runs `markdownlint-cli2` automatically after every `Write` or `Edit`
on `.md` and `.qmd` files. No manual lint step is needed after edits in this session.

Pre-commit hooks (`.pre-commit-config.yaml`) enforce the same lint rules on commit.

## Two Quarto Configurations

`src/_quarto.yml` — **book** format used for Word export. Do not overwrite it permanently.
`src/_quarto-website.yml` — **website** format used for HTML/GitLab Pages.

CI builds both by temporarily swapping the files and running from within `src/`:

```bash
cp src/_quarto.yml src/_quarto-book.yml
cp src/_quarto-website.yml src/_quarto.yml
cd src/ && quarto render          # website
cp src/_quarto-book.yml src/_quarto.yml
cd src/ && quarto render --to docx
```

When editing locally, always restore `src/_quarto.yml` to the book format after a website build.
`uv run sdlc/ci/build-scripts/render_website.py` does this automatically and is the preferred local method.

## Structure

All book content lives under `src/`. Add new sections there and register them in both Quarto configs.

| Path | Domain |
| --- | --- |
| `src/index.qmd` | Book introduction / home page |

## Adding a Nested Page to a Section

Every section folder has `index.qmd` as its landing page. Sub-pages nest in Word via `{{< include >}}`
— do NOT use `part:` or `shift-heading-level-by` (they don't produce TOC nesting in docx).

**Heading levels by depth:**

| Depth | Starts with |
| --- | --- |
| Section root (listed in `_quarto.yml`) | `# Title` |
| Sub-page | `## Title` |
| Sub-sub-page | `### Title` |

**Sub-page frontmatter** — always add `title:` (used by the website sidebar):

```yaml
---
title: "My Sub-page"
---

## My Sub-page
...
```

**Book wiring** — `_quarto.yml` lists only top-level `index.qmd` files. All sub-pages (including
depth-2) are included directly from the top-level chapter — never from an intermediate `index.qmd`:

```markdown
# In src/section/index.qmd:
{{< include sub-page.qmd >}}
{{< include sub-section/index.qmd >}}
{{< include sub-section/deep-page.qmd >}}   ← NOT inside sub-section/index.qmd
```

Reason: Quarto resolves all include paths relative to the top-level chapter's directory. A
sub-section `index.qmd` is also a standalone website page, so its includes would break in one of
the two contexts. Keep all includes at the top level.

**Image paths** — write relative to the file's own location. The `fix_image_paths.lua` filter
(registered in `src/_quarto.yml`) corrects depth-2 paths for docx automatically. Do not change them:

| Depth | Image path |
| --- | --- |
| Root chapter | `.attachments/...` |
| Depth-1 sub-page | `../.attachments/...` |
| Depth-2 sub-page | `../../.attachments/...` |

**Checklist for a new sub-page:**

1. Create `.qmd` with `title:` frontmatter and heading at correct depth (`##` or `###`)
2. Add `{{< include >}}` in the **top-level** section `index.qmd` using the path from that file's directory
3. Register in `_quarto-website.yml` sidebar — do NOT add to `_quarto.yml`
4. Use the correct image path depth convention above
5. Cross-links must reference `<folder>/index.qmd`, not the folder itself

## Python

Always use the local virtual environment `.venv` for Python and `uv` commands:

```bash
# Create .venv and install dependencies
uv sync

# Run Python (cross-platform — resolves to the .venv interpreter)
uv run python

# Direct interpreter path (platform-specific, prefer `uv run` above)
.venv/bin/python        # macOS / Linux
.venv\Scripts\python    # Windows

# Run uv commands (installs into .venv automatically)
uv run <script>
uv add <package>
```

Never use the system Python or a global `pip install`.

## Linting Rules

`.markdownlint-md.yml` (for `.md` files — always pass via `--config .markdownlint-md.yml`):

- Max line length 120, tables and code blocks exempt (`MD013`)
- Allows `<div>`, `<redoc>`, `<script>` HTML elements (`MD033`)
- `MD036`, `MD041` disabled

`.markdownlint-qmd.yml` (for `.qmd` files — always pass via `--config .markdownlint-qmd.yml`):

- Line length check disabled — `MD013: false` (frontmatter and code blocks make it impractical)
- HTML inline allowed — `MD033: false` (Quarto shortcodes and callouts use raw HTML)
- `MD028`, `MD036`, `MD041`, `MD051` disabled

# New Book

Source for the **New Book** book.
This repository is a general-purpose documentation template — not tied to any specific domain.
It is published as both a website and a downloadable Word document.

## 1. Web Version

The rendered documentation is published and available at:

**[https://your-gitlab-pages-url](https://your-gitlab-pages-url)**

A Word version of the full book is downloadable from the same URL as `*.docx`.

## 2. Tooling

Documentation is managed with [Quarto](https://quarto.org/) and published as both a website and a Word document.
Source files are written in `.qmd` (Quarto Markdown).
The site is built and deployed automatically via GitLab CI/CD on every push to `main`.

Two Quarto configurations are used:

| File | Purpose | Output |
| --- | --- | --- |
| `src/_quarto.yml` | Book — used for Word export | `_book/*.docx` |
| `src/_quarto-website.yml` | Website — deployed to GitLab Pages | `_site/` → `public/` |

## 3. Local Development

### 3.1. Prerequisites

- [Quarto CLI](https://quarto.org/docs/get-started/) installed
- [Node.js](https://nodejs.org/) (for markdownlint):

```bash
npm install -g markdownlint-cli2
```

> CI uses `ghcr.io/quarto-dev/quarto:latest`.
> Python packages (`jupyter ipykernel`) are available via `uv` — see section 3.5.

### 3.2. Preview (website format)

```bash
cd src && quarto preview
```

### 3.3. Build HTML website

```bash
cp src/_quarto-website.yml src/_quarto.yml && cd src && quarto render
```

Output is written to `_site/`.

### 3.4. Build Word document

```bash
cd src && quarto render --to docx
```

Output is written to `_book/*.docx`.

### 3.5. Python environment

```bash
# Install uv (if not already installed)
pip install uv

# Create .venv and install dependencies
uv sync

# Run the website render script (handles config swap automatically)
uv run sdlc/ci/build-scripts/render_website.py
```

### 3.6. Lint

```bash
markdownlint-cli2 "**/*.md" --config .markdownlint-md.yml
markdownlint-cli2 "**/*.qmd" --config .markdownlint-qmd.yml
```

## 4. Adding Content

When adding a new page, register it in **both** `src/_quarto.yml` (under `book.chapters`) and
`src/_quarto-website.yml` (under `website.sidebar.contents` and `website.navbar`).

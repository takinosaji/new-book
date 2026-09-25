---
name: x-init-fork
description: Adapt a fresh fork of the new-book Quarto template to a new book — rename title, slug, author, URLs,
  reset the version, and replace placeholder content.
---

Execute the following steps in order. Do not skip any step.

---

## Step 1 — Collect book information

Ask the user the following questions **all at once in a single message**:

1. **Book title** — the human-readable title shown on the website, the Word cover page, and README heading
   (e.g. `Payments Platform Architecture`).
2. **Description** — one or two sentences describing what the book covers. Used for the website `description`,
   the README introduction, the `CLAUDE.md` project summary, and the opening paragraph of `src/index.qmd`.
3. **Authors** — one or more `Name <email>` pairs (email optional). The first author is also used in the website
   footer copyright.
4. **Initial version** — the starting `X.Y.Z` version (default `0.1.0`).
5. **Published website URL** — the GitLab Pages URL where the site will live, or `none` if not known yet.
6. **Repository URL** — the source repository link shown as an icon in the website footer, or `none` to drop the icon.
7. **Placeholder content in `src/index.qmd`**:
   - `minimal` — replace the introduction page with a short stub using the title and description (default)
   - `keep` — keep the sample structure (Purpose, Overview, How to Use, Contributing) and only substitute names;
     the demo image stays until you replace it

Wait for the user to submit all answers before continuing.

---

## Step 2 — Derive and confirm identifiers

From the title, derive:

- `KEBAB` — lowercase ASCII with hyphens, e.g. `payments-platform-architecture`. Used for `book.output-file`
  (the docx is named `<KEBAB>-<version>.docx`) and the `pyproject.toml` package name.

From the repository URL (if given), derive the footer icon:

- `github` if the host is `github.com`, otherwise `gitlab`.

Show the user a confirmation block like:

```text
Derived values — please confirm or correct:

  Title        : Payments Platform Architecture
  Slug         : payments-platform-architecture
  Docx output  : _book/payments-platform-architecture-0.1.0.docx
  Version      : 0.1.0
  Authors      : Jane Doe <jane@example.com>
  Website URL  : https://example.gitlab.io/payments-platform-architecture
  Repo URL     : https://gitlab.example.com/group/payments-platform-architecture  (icon: gitlab)
  index.qmd    : minimal
```

**Wait for explicit confirmation before proceeding.** If the user corrects any value, update it and show the corrected
block again before moving on.

---

## Step 3 — Safety check

Verify that `src/_quarto.yml` exists and still contains `title: "New Book"` and `output-file: "new-book"`.
If it does not, tell the user:

> "This does not look like a fresh fork of `new-book` (the template title/slug was not found in
> `src/_quarto.yml`). Proceeding may produce incorrect results."

Ask whether to continue anyway. If the user says no, stop without making any changes.

---

## Step 4 — Update the book config (`src/_quarto.yml`)

Edit only the `book:` block. Leave `filters:` and `format:` untouched — CI depends on them.

| Field | Template value | New value |
| --- | --- | --- |
| `book.title` | `"New Book"` | `"<TITLE>"` |
| `book.subtitle` | `"Version 1.0.0"` | `"Version <VERSION>"` — keep the exact `Version X.Y.Z` form; `book_config.py` parses it |
| `book.output-file` | `"new-book"` | `"<KEBAB>"` |
| `book.author` | `Author Name` / `author@example.com` | one `- name:` entry per author, `email:` only when given |

Do **not** add chapters here — `book.chapters` lists only top-level section `index.qmd` files (see `CLAUDE.md`).

---

## Step 5 — Update the website config (`src/_quarto-website.yml`)

| Field | Template value | New value |
| --- | --- | --- |
| `website.title` | `"New Book"` | `"<TITLE>"` |
| `website.description` | `"Project documentation."` | `"<DESCRIPTION>"` |
| `website.site-url` | `""` | website URL, or leave `""` if `none` |
| `website.page-footer.left` | `"© Author Name"` | `"© <first author name>"` |
| `website.page-footer.right` | `icon: github`, `href: ""` | `icon: <github\|gitlab>`, `href: "<REPO_URL>"` |

If the repository URL is `none`, remove the whole `right:` list from `page-footer`.

---

## Step 6 — Rename the Python project

1. In `pyproject.toml` set `name = "<KEBAB>"` and `version = "<VERSION>"`.
2. Run `uv lock` to refresh `uv.lock` (never edit it by hand).

---

## Step 7 — Replace placeholder content in `src/index.qmd`

The page must keep `# Introduction {.unnumbered}` as its first heading — it is the book's first chapter.

**If `minimal`:**

Replace the whole file with a stub like:

```markdown
# Introduction {.unnumbered}

<DESCRIPTION>

## How to Use This Book

Navigate using the sidebar. If you are new, read top to bottom.
If you are looking for something specific, use the search box.
```

Then delete `src/.attachments/demo.png`. If `src/.attachments/` becomes empty, delete the directory too.

**If `keep`:**

- Replace `**Project Name**` with `**<TITLE>**`.
- Replace the first paragraph's second sentence with `<DESCRIPTION>` if it reads better; otherwise leave it.
- Leave the demo image and section table in place; they are listed as remaining manual steps.

---

## Step 8 — Update README.md

1. Replace the `# New Book` heading with `# <TITLE>`.
2. Replace the introduction paragraph (`Source for the **New Book** book.` … `not tied to any specific domain.`) with
   `<DESCRIPTION>`, keeping the sentence about website + Word document outputs.
3. In section **1. Web Version**, replace `https://your-gitlab-pages-url` (both the link text and target) with the
   website URL. If the URL is `none`, keep the placeholder and list it as a remaining manual step.
4. Remove section **5. Adapting This Template** entirely — it is template-only content.

---

## Step 9 — Update CLAUDE.md

1. Replace the first line of the **Project** section (`Architecture documentation built with [Quarto](...)`) with
   `<DESCRIPTION>` followed by `Built with [Quarto](https://quarto.org/).`
2. Leave all tooling rules (version, commands, two configs, nesting, linting, Python) unchanged — they describe the
   template mechanics, which the fork keeps.

---

## Step 10 — Final checks

**10a — Template remnants:** grep for leftover template strings:

```bash
grep -rnE "New Book|new-book|Author Name|author@example\.com|your-gitlab-pages-url|Project Name|Project documentation" \
  --exclude-dir=.venv --exclude-dir=.git --exclude-dir=_book --exclude-dir=_site \
  --exclude-dir=.quarto --exclude-dir=.serena --exclude-dir=__pycache__ \
  --exclude=uv.lock \
  .
```

Ignore matches inside this skill file and `.claude/settings.local.json` (machine-local, git-ignored). List every other
match to the user and fix it before continuing.

**10b — Lint:**

```bash
markdownlint-cli2 "**/*.md" --config .markdownlint-md.yml
markdownlint-cli2 "**/*.qmd" --config .markdownlint-qmd.yml
```

**10c — Version wiring:** confirm `book_config.py` reads the new values:

```bash
uv run python sdlc/ci/build-scripts/book_config.py
```

Expected output: `<KEBAB> <VERSION>`.

**10d — Render both outputs** (only if `quarto` is on `PATH`; otherwise list it as a manual step):

```bash
uv run sdlc/ci/build-scripts/render_website.py
uv run sdlc/ci/build-scripts/render_book.py
```

Confirm `_site/index.html` exists and `_book/<KEBAB>-<VERSION>.docx` exists, and that `git status` shows
`src/_quarto.yml` still in **book** format (the website script restores it). Fix any failure before continuing.

---

## Step 11 — Print completion summary

Output a summary of what was done and what remains for the user:

```text
Fork initialised.

  Title    : <TITLE>
  Slug     : <KEBAB>
  Version  : <VERSION>
  Docx     : _book/<KEBAB>-<VERSION>.docx

Actions completed:
  ✓ Book config (title, subtitle, output-file, authors) updated
  ✓ Website config (title, description, site-url, footer) updated
  ✓ pyproject.toml renamed and uv.lock refreshed
  ✓ index.qmd: <minimal | kept, names substituted>
  ✓ README template section (5) removed
  ✓ CLAUDE.md project summary updated
  ✓ Lint and render checks passed

Remaining manual steps:
```

Then print only the items that apply:

- `[ ] Add your first section — create src/<section>/index.qmd, list it in src/_quarto.yml book.chapters and
  in src/_quarto-website.yml sidebar/navbar (see "Adding a Nested Page" in CLAUDE.md)`
- (if website URL = `none`) `[ ] Set website.site-url in src/_quarto-website.yml and the link in README section 1`
- (if repo URL = `none`) `[ ] Add a repository icon to page-footer.right in src/_quarto-website.yml if wanted`
- (if `keep`) `[ ] Replace src/.attachments/demo.png and the placeholder section table in src/index.qmd`
- `[ ] Replace src/reference.docx if the Word output needs different styles`
- `[ ] Set the EXTERNAL_CHECKS_URL CI variable used by sdlc/ci/pipeline-scripts/invoke-ai-pipeline.sh, or remove
  the "Invoke AI/Run CodeMie Pipeline" job from .gitlab-ci.yml`
- (if 10d was skipped) `[ ] Render the website and docx locally once Quarto is installed`
- `[ ] Point the git remotes at the new repository (git remote -v still shows the template's)`
- `[ ] Start a new Claude Code session so the updated CLAUDE.md is picked up`

#!/bin/sh
set -e
npm install -g markdownlint-cli2
markdownlint-cli2 "**/*.md" "!.venv/**" "!node_modules/**" "!_site/**" "!_book/**" --config .markdownlint-md.yml
markdownlint-cli2 "**/*.qmd" --config .markdownlint-qmd.yml

#!/bin/sh
set -e
cp src/_quarto-website.yml src/_quarto.yml
cd src/ && quarto render && cd ..
mv _site public

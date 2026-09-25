#!/bin/sh
set -e

apt-get update -qq && apt-get install -y -qq unzip python3 python3-pip fonts-noto-color-emoji \
    libglib2.0-0 libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
    libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
    libgbm1 libasound2 libpango-1.0-0 libcairo2

quarto install chrome-headless-shell --no-prompt

CHROME=$(find /root ~/.local /home -name "chrome-headless-shell" -type f 2>/dev/null | head -1)
if [ -z "$CHROME" ]; then echo "ERROR: chrome-headless-shell not found"; exit 1; fi
REAL="${CHROME}.real"
mv "$CHROME" "$REAL"
printf '#!/bin/sh\nexec "%s" --no-sandbox --disable-dev-shm-usage --disable-setuid-sandbox --disable-gpu "$@"\n' "$REAL" > "$CHROME"
chmod +x "$CHROME"

python3 -m pip install --quiet python-docx lxml

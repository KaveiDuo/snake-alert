#!/usr/bin/env bash
# Builds the web version for GitHub Pages (https://kaveiduo.github.io/snake-alert/app/).
# For a local preview served from the site root, run: BASE_HREF=/ ./build_web.sh
# The scanner's free Gemini key is read from scanner_key.txt (not committed) and
# passed in reversed, so the raw key never appears in the published files.
set -e
cd "$(dirname "$0")"
KEY_R=""
if [ -f scanner_key.txt ]; then KEY_R=$(tr -d ' \r\n' < scanner_key.txt | perl -ne 'print scalar reverse'); fi
# Optional backup scanner (Groq), from groq_key.txt (not committed), also reversed.
GROQ_R=""
if [ -f groq_key.txt ]; then GROQ_R=$(tr -d ' \r\n' < groq_key.txt | perl -ne 'print scalar reverse'); fi
MSYS_NO_PATHCONV=1 flutter build web --release --base-href "${BASE_HREF:-/snake-alert/app/}" --dart-define=SCANNER_KEY_R="$KEY_R" --dart-define=GROQ_KEY_R="$GROQ_R"
# No offline service worker: this one clears caches left by older versions.
cp web/sw_cleanup.js build/web/flutter_service_worker.js
rm -f build/web/sw_cleanup.js
echo "Web build ready: build/web"

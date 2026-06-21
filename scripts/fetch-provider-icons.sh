#!/bin/bash
# Fetch brand icons from Simple Icons (CC0) + Lobe Icons (MIT) for Deskline HUD.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROV="$ROOT/Sources/Resources/Providers"
SVG_DIR="$PROV/SVG"
mkdir -p "$SVG_DIR"

SI="https://cdn.jsdelivr.net/npm/simple-icons@v14/icons"
fetch_si() {
  local name="$1" slug="$2"
  curl -sfL "$SI/${slug}.svg" -o "$SVG_DIR/${name}.svg"
  rsvg-convert -w 64 -h 64 "$SVG_DIR/${name}.svg" -o "$PROV/${name}.png"
  echo "  ✓ $name ← simple-icons/$slug"
}

echo "Fetching provider icons…"
fetch_si codex openai
fetch_si gemini googlegemini
# Claude Code: colorful mark from Lobe Icons (MIT) — not Anthropic corporate logo.
CURSOR_URL="https://raw.githubusercontent.com/lobehub/lobe-icons/master/packages/static-png/light/cursor.png"
CLAUDE_URL="https://raw.githubusercontent.com/lobehub/lobe-icons/master/packages/static-png/light/claude-color.png"
curl -sfL "$CLAUDE_URL" -o "$PROV/claude-src.png"
sips -z 64 64 "$PROV/claude-src.png" --out "$PROV/claude.png" >/dev/null
rm -f "$PROV/claude-src.png"
echo "  ✓ claude ← lobehub/lobe-icons (claude-color)"

curl -sfL "$SI/google.svg" -o "$SVG_DIR/antigravity.svg"
rsvg-convert -w 64 -h 64 "$SVG_DIR/antigravity.svg" -o "$PROV/antigravity.png"
echo "  ✓ antigravity ← simple-icons/google (Antigravity has no SI entry yet)"

curl -sfL "$CURSOR_URL" -o "$PROV/cursor-src.png"
sips -z 64 64 "$PROV/cursor-src.png" --out "$PROV/cursor.png" >/dev/null
rm -f "$PROV/cursor-src.png"
echo "  ✓ cursor ← lobehub/lobe-icons"

RES="$ROOT/Sources/Resources"
rsvg-convert -w 18 -h 18 "$RES/menubar-icon.svg" -o "$RES/menubar-icon.png"
rsvg-convert -w 1024 -h 1024 "$RES/app-icon.svg" -o "$ROOT/icon.png"
echo "Done. Icons in $PROV"

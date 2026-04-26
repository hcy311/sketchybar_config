#!/bin/zsh

set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "Missing dependency: gh" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Missing dependency: jq" >&2
  exit 1
fi

SCRIPT_DIR=${0:A:h}
CONFIG_DIR=${SCRIPT_DIR:h}
BASE_MAP_PATH="$CONFIG_DIR/helpers/app_icons_base.lua"
FONT_PATH="$CONFIG_DIR/fonts/sketchybar-app-font.ttf"
USER_FONT_PATH="$HOME/Library/Fonts/sketchybar-app-font.ttf"
REPO="kvndrsslr/sketchybar-app-font"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

release_json="$(gh release view --repo "$REPO" --json tagName,assets)"
tag_name="$(printf '%s' "$release_json" | jq -r '.tagName')"
font_url="$(printf '%s' "$release_json" | jq -r '.assets[] | select(.name == "sketchybar-app-font.ttf") | .url')"
map_url="$(printf '%s' "$release_json" | jq -r '.assets[] | select(.name == "icon_map.lua") | .url')"

if [[ -z "$font_url" || "$font_url" == "null" ]]; then
  echo "Could not find sketchybar-app-font.ttf in $REPO release $tag_name" >&2
  exit 1
fi

if [[ -z "$map_url" || "$map_url" == "null" ]]; then
  echo "Could not find icon_map.lua in $REPO release $tag_name" >&2
  exit 1
fi

curl -L "$font_url" -o "$tmpdir/sketchybar-app-font.ttf"
curl -L "$map_url" -o "$tmpdir/icon_map.lua"

cp "$tmpdir/sketchybar-app-font.ttf" "$FONT_PATH"
cp "$tmpdir/sketchybar-app-font.ttf" "$USER_FONT_PATH"
cp "$tmpdir/icon_map.lua" "$BASE_MAP_PATH"

if command -v sketchybar >/dev/null 2>&1; then
  sketchybar --trigger forced >/dev/null 2>&1 || true
fi

launchctl kickstart -k "gui/$(id -u)/homebrew.mxcl.sketchybar" >/dev/null 2>&1 || true

echo "Updated sketchybar-app-font to $tag_name"
echo "Base map: $BASE_MAP_PATH"
echo "Font: $FONT_PATH"
echo "Installed font: $USER_FONT_PATH"

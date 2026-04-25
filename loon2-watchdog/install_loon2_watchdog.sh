#!/bin/zsh

set -euo pipefail

BASE_DIR="$HOME/.config/sketchybar/loon2-watchdog"
PLIST_SRC="$BASE_DIR/com.hcy.loon2-watchdog.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.hcy.loon2-watchdog.plist"
SCRIPT_PATH="$BASE_DIR/ensure_loon2_running.sh"

/bin/mkdir -p "$HOME/Library/LaunchAgents"
/bin/chmod +x "$SCRIPT_PATH"
/bin/cp "$PLIST_SRC" "$PLIST_DST"

/bin/launchctl bootout "gui/$(id -u)/com.hcy.loon2-watchdog" >/dev/null 2>&1 || true
/bin/launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
/bin/launchctl kickstart -k "gui/$(id -u)/com.hcy.loon2-watchdog"

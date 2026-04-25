#!/bin/zsh

set -u

APP_NAME="Loon 2"
APP_PATH="/Applications/Loon 2.app"
TUNNEL_PATTERN="LoonTunnelProvider"
LOG_FILE="/tmp/loon2-watchdog.log"

timestamp() {
  /bin/date '+%Y-%m-%d %H:%M:%S'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$1" >> "$LOG_FILE"
}

if /usr/bin/pgrep -f "$TUNNEL_PATTERN" >/dev/null 2>&1; then
  exit 0
fi

if [ ! -d "$APP_PATH" ]; then
  log "app missing at $APP_PATH"
  exit 1
fi

log "provider missing, reopening $APP_NAME in background"
/usr/bin/open -gj -a "$APP_NAME"

#!/bin/zsh

set -u

TARGET_BUNDLE_ID="${LOON_WATCHDOG_BUNDLE_ID:-com.ruikq.decar}"
APP_NAME=""
TUNNEL_PATTERN="LoonTunnelProvider"
LOG_FILE="/tmp/loon2-watchdog.log"

timestamp() {
  /bin/date '+%Y-%m-%d %H:%M:%S'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$1" >> "$LOG_FILE"
}

case "$TARGET_BUNDLE_ID" in
  com.ruikq.decar) APP_NAME="Loon 2" ;;
  com.loon.Loon) APP_NAME="Loon" ;;
  *)
    log "unsupported target bundle id: $TARGET_BUNDLE_ID"
    exit 1
    ;;
esac

if /usr/bin/pgrep -f "$TUNNEL_PATTERN" >/dev/null 2>&1; then
  exit 0
fi

if ! /usr/bin/osascript -e 'id of app "'"$APP_NAME"'"' >/dev/null 2>&1; then
  log "app not resolvable for target bundle id: $TARGET_BUNDLE_ID"
  exit 1
fi

log "provider missing, reopening $APP_NAME ($TARGET_BUNDLE_ID) in background"
/usr/bin/open -gj -a "$APP_NAME"

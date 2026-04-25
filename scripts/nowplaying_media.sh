#!/bin/sh

NP_BIN="${NOWPLAYING_CLI:-/opt/homebrew/bin/nowplaying-cli}"
if [ ! -x "$NP_BIN" ]; then
  NP_BIN="$(command -v nowplaying-cli 2>/dev/null || true)"
fi

[ -x "$NP_BIN" ] || exit 0

raw="$("$NP_BIN" get-raw 2>/dev/null)" || exit 0
[ -n "$raw" ] || exit 0

extract_raw() {
  key="$1"
  printf '%s\n' "$raw" | awk -v key="\"$key\"" '
    index($0, key) {
      sub(/^[^:]*:[[:space:]]*/, "")
      sub(/,$/, "")
      sub(/^"/, "")
      sub(/"$/, "")
      print
      exit
    }
  '
}

title="$(extract_raw 'kMRMediaRemoteNowPlayingInfoTitle' | tr '\t\r\n' '   ')"
artist="$(extract_raw 'kMRMediaRemoteNowPlayingInfoArtist' | tr '\t\r\n' '   ')"
bundle="$(extract_raw 'kMRMediaRemoteNowPlayingInfoClientBundleIdentifier' | tr '\t\r\n' '   ')"
rate="$(extract_raw 'kMRMediaRemoteNowPlayingInfoPlaybackRate' | tr '\t\r\n' '   ')"

case "$bundle" in
  com.apple.Music) app="Music" ;;
  com.spotify.client) app="Spotify" ;;
  *) app="" ;;
esac

case "$rate" in
  1|1.*) state="playing" ;;
  0|0.*) state="paused" ;;
  *) state="stopped" ;;
esac

if [ -z "$title$artist$app" ]; then
  state="stopped"
fi

printf '%s\t%s\t%s\t%s\n' "$app" "$state" "$title" "$artist"

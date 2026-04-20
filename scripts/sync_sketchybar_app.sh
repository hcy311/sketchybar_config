#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
APP_DIR="$CONFIG_DIR/SketchyBar.app"
APP_BIN="$APP_DIR/Contents/MacOS/sketchybar"
LABEL="com.hcy.sketchybar"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
HOMEBREW_LABEL="homebrew.mxcl.sketchybar"
HOMEBREW_PLIST="$HOME/Library/LaunchAgents/$HOMEBREW_LABEL.plist"
BREW_BIN="$(brew --prefix sketchybar)/bin/sketchybar"
SKETCHYBAR_VERSION="$("$BREW_BIN" --version | sed 's/^sketchybar-v//')"
USER_ID="$(id -u)"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BREW_BIN" "$APP_BIN"
chmod +x "$APP_BIN"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>sketchybar</string>
  <key>CFBundleIdentifier</key>
  <string>git.felix.sketchybar</string>
  <key>CFBundleName</key>
  <string>SketchyBar</string>
  <key>CFBundleDisplayName</key>
  <string>SketchyBar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$SKETCHYBAR_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$SKETCHYBAR_VERSION</string>
  <key>LSBackgroundOnly</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - --identifier git.felix.sketchybar "$APP_DIR"

if command -v swiftc >/dev/null 2>&1; then
  swiftc -module-cache-path /tmp/sketchybar-swift-cache \
    "$CONFIG_DIR/scripts/wallpaper_color.swift" \
    -o "$CONFIG_DIR/scripts/wallpaper_color"
fi

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$APP_BIN</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>CONFIG_DIR</key>
    <string>$CONFIG_DIR</string>
    <key>LANG</key>
    <string>en_US.UTF-8</string>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ProcessType</key>
  <string>Interactive</string>
  <key>LimitLoadToSessionType</key>
  <array>
    <string>Aqua</string>
    <string>Background</string>
    <string>LoginWindow</string>
    <string>StandardIO</string>
    <string>System</string>
  </array>
  <key>StandardOutPath</key>
  <string>/opt/homebrew/var/log/sketchybar/sketchybar.out.log</string>
  <key>StandardErrorPath</key>
  <string>/opt/homebrew/var/log/sketchybar/sketchybar.err.log</string>
</dict>
</plist>
PLIST

if command -v brew >/dev/null 2>&1; then
  brew services stop sketchybar >/dev/null 2>&1 || true
fi

launchctl bootout "gui/$USER_ID/$HOMEBREW_LABEL" 2>/dev/null || true
if [ -f "$HOMEBREW_PLIST" ]; then
  launchctl bootout "gui/$USER_ID" "$HOMEBREW_PLIST" 2>/dev/null || true
fi

if launchctl print "gui/$USER_ID/$LABEL" >/dev/null 2>&1; then
  launchctl kickstart -k "gui/$USER_ID/$LABEL"
else
  launchctl bootstrap "gui/$USER_ID" "$PLIST"
fi

echo "SketchyBar.app synced from $BREW_BIN and $LABEL reloaded."

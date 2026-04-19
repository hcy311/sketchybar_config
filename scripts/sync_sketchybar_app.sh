#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
APP_DIR="$CONFIG_DIR/SketchyBar.app"
APP_BIN="$APP_DIR/Contents/MacOS/sketchybar"
PLIST="$HOME/Library/LaunchAgents/homebrew.mxcl.sketchybar.plist"
BREW_BIN="$(brew --prefix sketchybar)/bin/sketchybar"
SKETCHYBAR_VERSION="$("$BREW_BIN" --version | sed 's/^sketchybar-v//')"

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

/usr/libexec/PlistBuddy -c "Set :ProgramArguments:0 $APP_BIN" "$PLIST"
if ! /usr/libexec/PlistBuddy -c "Set :EnvironmentVariables:CONFIG_DIR $CONFIG_DIR" "$PLIST" 2>/dev/null; then
  /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:CONFIG_DIR string $CONFIG_DIR" "$PLIST"
fi

launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "SketchyBar.app synced from $BREW_BIN and LaunchAgent reloaded."

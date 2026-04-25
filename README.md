# SketchyBar Config

A personal SketchyBar setup built with the Lua API, tuned for macOS daily use and designed to be reproducible on other machines.

Chinese documentation: [README_CN.md](README_CN.md)

## Features

- Lua-based SketchyBar configuration with modular items under `items/`.
- Homebrew SketchyBar binary workflow with a helper script for local code signing and Accessibility TCC repair.
- Optional macOS Accessibility-friendly `SketchyBar.app` wrapper generated locally from the Homebrew binary.
- Wallpaper-aware Material You-style bar color generated at SketchyBar startup, biased toward pleasant top-of-wallpaper surface tones.
- Automatic light/dark mode support. In light mode, foreground text and icons switch to dark colors; in dark mode they use light colors.
- Mission Control spaces with per-space app icons.
- Front app display and clickable menu/spaces switching.
- Apple menu and macOS menu bar item integration through the helper binary.
- Calendar and clock widget.
- Battery widget with remaining-time popup.
- Volume widget with output device popup and scroll-to-adjust support.
- Wi-Fi/network throughput widget with popup details and click-to-copy fields.
- Wi-Fi popup with generalized proxy detection for Clash Verge, Quantumult X, Shadowrocket, and Loon.
- CPU graph widget using a small local event provider.
- Media widget for Spotify/Music playback artwork and controls.
- WeChat, QQ, WhatsApp, and Telegram unread badge widgets that auto-hide when the apps are not running.
- Icon-only caffeine widget for toggling `caffeinate -dimsu`.
- Optional `Loon` watchdog folder for users who rely on the App Store / iPad build of Loon on macOS.

## Requirements

- macOS
- [SketchyBar](https://github.com/FelixKratz/SketchyBar), installed with Homebrew
- Lua 5.5 and the SketchyBar Lua bridge from [SbarLua](https://github.com/FelixKratz/SbarLua)
- Xcode Command Line Tools, used to build helper binaries and the Swift wallpaper color helper
- Hack Nerd Font for the WeChat/QQ icons
- `sketchybar-app-font` for the app icons shown in spaces and the front-app item

## Important Warning

This config currently uses `scripts/sign_and_grant_accessibility.sh` to repair SketchyBar's macOS Accessibility permission when the normal System Settings flow fails.

Read this before running it:

- The script directly edits the system TCC database at `/Library/Application Support/com.apple.TCC/TCC.db`.
- It asks for an administrator password and writes Accessibility allow rows manually.
- It re-signs the Homebrew-installed SketchyBar binary with a local self-signed Code Signing certificate.
- This is a workaround for a macOS TCC/signature mismatch. It is not an official Apple or SketchyBar flow.
- Homebrew upgrades replace the SketchyBar binary, so the signature and TCC code requirement can stop matching. Run the script again after every SketchyBar upgrade.
- Back up the TCC database before experimenting further, and prefer rebooting/logging out after major permission changes if macOS behaves inconsistently.

## Installation

Clone the repo into the standard SketchyBar config path:

```sh
git clone git@github.com:hcy311/sketchybar_config.git ~/.config/sketchybar
cd ~/.config/sketchybar
./scripts/sign_and_grant_accessibility.sh
```

The script signs the Homebrew SketchyBar binary with a local Code Signing certificate, writes the matching Accessibility entry into the system TCC database, and restarts the Homebrew LaunchAgent.

If you prefer the app-wrapper workaround instead, run:

```sh
./scripts/sync_sketchybar_app.sh
```

Then add `~/.config/sketchybar/SketchyBar.app` in `System Settings` -> `Privacy & Security` -> `Accessibility`.

## Updating SketchyBar

After upgrading SketchyBar with Homebrew, the binary changes and macOS may stop matching the old Accessibility code requirement. Re-sign and re-grant Accessibility:

```sh
brew upgrade sketchybar
cd ~/.config/sketchybar
./scripts/sign_and_grant_accessibility.sh
```

`scripts/sign_and_grant_accessibility.sh` does the following:

- Creates a local self-signed Code Signing certificate if one does not already exist.
- Re-signs the current Homebrew SketchyBar binary.
- Forces the Homebrew LaunchAgent to start `/opt/homebrew/bin/sketchybar`.
- Generates the current code requirement with `csreq`.
- Writes Accessibility allow rows into `/Library/Application Support/com.apple.TCC/TCC.db` for the Homebrew, opt, and Cellar paths.
- Restarts `tccd` and `homebrew.mxcl.sketchybar`.

The older app-wrapper script, `scripts/sync_sketchybar_app.sh`, remains available as a fallback. It builds `SketchyBar.app`, signs it, compiles `scripts/wallpaper_color.swift`, installs the dedicated `com.hcy.sketchybar` LaunchAgent, and reloads SketchyBar.

`SketchyBar.app` is intentionally ignored by git because it contains a generated Homebrew binary copy and an ad-hoc signature. It should be regenerated per installation instead of committed.

## Fonts

This repo bundles the redistributable fonts needed by the config:

- [fonts/HackNerdFont-Regular.ttf](fonts/HackNerdFont-Regular.ttf)
- [fonts/sketchybar-app-font.ttf](fonts/sketchybar-app-font.ttf)

Install them with:

```sh
cp fonts/*.ttf ~/Library/Fonts/
```

`SF Pro` and `SF Mono` are still referenced by the config, but they are Apple fonts and are not committed to this repository.

## Proxy Detection

The Wi-Fi widget also acts as a proxy status indicator.

- Supported apps: `Clash Verge`, `Quantumult X`, `Shadowrocket`, and `Loon`
- The popup includes `Proxy: <app> <status>`
- The Wi-Fi icon color reflects the current proxy state when network connectivity is up
- Detection is whitelist-based, so unrelated VPN tools such as `Tailscale` or `AdGuard` are intentionally ignored

Current logic prefers macOS network service state from `scutil --nc list`, then combines that with:

- whether a `utun` interface exists
- whether the expected helper / tunnel process for the detected proxy app exists

State meanings:

- `on`: whitelisted proxy is connected, `utun` exists, and the expected process exists
- `off`: no active whitelisted proxy connection
- `error`: proxy VPN looks connected, but the expected helper / tunnel process is missing

Important Loon note:

- The status item displays `Loon`
- The detection supports both `Loon.app` and `Loon 2.app`
- The App Store / iPad build may appear under either name depending on install history and how macOS exposed the bundle
- The native macOS build and the App Store / iPad build can therefore share similar display names, so the implementation matches both known bundle identifiers
- Known bundle ids:
  - `com.loon.Loon` for the native macOS build
  - `com.ruikq.decar` for the App Store / iPad build
- The UI label stays `Loon` regardless of which bundle is detected

## Loon iPad Watchdog

The repo includes a standalone [loon2-watchdog](loon2-watchdog) folder for users who want to keep Loon alive on macOS.

- It checks whether `LoonTunnelProvider` is still alive
- If the provider has dropped, it reopens the configured Loon target in the background
- It is intentionally separate from the SketchyBar config so it can be used or removed independently
- It uses bundle ids instead of guessing by app name
- The default watchdog target is the App Store / iPad build bundle id `com.ruikq.decar`

## Generated Files

The following files are generated locally and ignored:

- `SketchyBar.app/`
- `helpers/**/bin/`
- `scripts/wallpaper_color`
- `.DS_Store`

## Useful Commands

Restart the actual LaunchAgent:

```sh
launchctl kickstart -k gui/$(id -u)/homebrew.mxcl.sketchybar
```

Send a refresh event to the already-running bar:

```sh
sketchybar --trigger forced
```

The `sketchybar` command in your shell usually resolves to `/opt/homebrew/bin/sketchybar`. The Homebrew LaunchAgent should point at that same path so Accessibility/TCC sees a stable client path.

Check the shell command path:

```sh
which sketchybar
```

Check the LaunchAgent target:

```sh
launchctl print gui/$(id -u)/com.hcy.sketchybar
launchctl print gui/$(id -u)/homebrew.mxcl.sketchybar
```

## References

- [FelixKratz/SketchyBar](https://github.com/FelixKratz/SketchyBar): the status bar itself and the official command/API reference.
- [FelixKratz/SbarLua](https://github.com/FelixKratz/SbarLua): the Lua bridge and the original Lua example structure this config is based on.
- [AIboy996/dotfiles sketchybar](https://github.com/AIboy996/dotfiles/tree/main/sketchybar): inspiration for the WeChat/QQ unread badge items.

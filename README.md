# SketchyBar Config

A personal SketchyBar setup built with the Lua API, tuned for macOS daily use and designed to be reproducible on other machines.

Chinese documentation: [README_CN.md](README_CN.md)

## Features

- Lua-based SketchyBar configuration with modular items under `items/`.
- macOS Accessibility-friendly `SketchyBar.app` wrapper generated locally from the Homebrew binary, launched through a dedicated `com.hcy.sketchybar` LaunchAgent.
- Wallpaper-aware Material You-style bar color generated at SketchyBar startup, biased toward pleasant top-of-wallpaper surface tones.
- Automatic light/dark mode support. In light mode, foreground text and icons switch to dark colors; in dark mode they use light colors.
- Mission Control spaces with per-space app icons.
- Front app display and clickable menu/spaces switching.
- Apple menu and macOS menu bar item integration through the helper binary.
- Calendar and clock widget.
- Battery widget with remaining-time popup.
- Volume widget with output device popup and scroll-to-adjust support.
- Wi-Fi/network throughput widget with popup details and click-to-copy fields.
- CPU graph widget using a small local event provider.
- Media widget for Spotify/Music playback artwork and controls.
- WeChat and QQ unread badge widgets that auto-hide when the apps are not running.
- Icon-only caffeine widget for toggling `caffeinate -dimsu`.

## Requirements

- macOS
- [SketchyBar](https://github.com/FelixKratz/SketchyBar), installed with Homebrew
- Lua 5.5 and the SketchyBar Lua bridge from [SbarLua](https://github.com/FelixKratz/SbarLua)
- Xcode Command Line Tools, used to build helper binaries and the Swift wallpaper color helper
- Hack Nerd Font for the WeChat/QQ icons

## Installation

Clone the repo into the standard SketchyBar config path:

```sh
git clone git@github.com:hcy311/sketchybar_config.git ~/.config/sketchybar
cd ~/.config/sketchybar
./scripts/sync_sketchybar_app.sh
```

Then open `System Settings` -> `Privacy & Security` -> `Accessibility`, add:

```text
~/.config/sketchybar/SketchyBar.app
```

Enable the toggle for `SketchyBar.app`.

## Updating SketchyBar

After upgrading SketchyBar with Homebrew, rebuild the local app wrapper:

```sh
brew upgrade sketchybar
cd ~/.config/sketchybar
./scripts/sync_sketchybar_app.sh
```

The script builds `SketchyBar.app`, signs it, compiles `scripts/wallpaper_color.swift`, stops the Homebrew-managed SketchyBar service, installs the dedicated `com.hcy.sketchybar` LaunchAgent, and reloads SketchyBar.

The dedicated LaunchAgent is used so Homebrew upgrades or `brew services` plist rewrites do not silently switch SketchyBar back to the raw Homebrew binary. If you intentionally run `brew services start sketchybar` later, run `./scripts/sync_sketchybar_app.sh` again afterwards.

`SketchyBar.app` is intentionally ignored by git because it contains a local copy of the Homebrew binary and a local ad-hoc signature. It should be regenerated on each machine instead of committed.

## Generated Files

The following files are generated locally and ignored:

- `SketchyBar.app/`
- `helpers/**/bin/`
- `scripts/wallpaper_color`
- `.DS_Store`

## Useful Commands

Restart the actual LaunchAgent:

```sh
launchctl kickstart -k gui/$(id -u)/com.hcy.sketchybar
```

Send a refresh event to the already-running bar:

```sh
sketchybar --trigger forced
```

The `sketchybar` command in your shell usually resolves to `/opt/homebrew/bin/sketchybar`. That is fine for sending commands to the running bar, but it should not be treated as the service launcher. The persistent service should be checked with `launchctl` and should point at `SketchyBar.app`.

Check the shell command path:

```sh
which sketchybar
```

Check the LaunchAgent target:

```sh
launchctl print gui/$(id -u)/com.hcy.sketchybar
```

## References

- [FelixKratz/SketchyBar](https://github.com/FelixKratz/SketchyBar): the status bar itself and the official command/API reference.
- [FelixKratz/SbarLua](https://github.com/FelixKratz/SbarLua): the Lua bridge and the original Lua example structure this config is based on.
- [AIboy996/dotfiles sketchybar](https://github.com/AIboy996/dotfiles/tree/main/sketchybar): inspiration for the WeChat/QQ unread badge items.

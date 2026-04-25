## Loon Watchdog

This folder contains a lightweight LaunchAgent watchdog for Loon on macOS.

The watchdog is bundle-id driven instead of app-name driven. This matters because users may have:

- the App Store / iPad build
- the native macOS build
- both installed at the same time

The default target is the App Store / iPad build bundle id:

- `com.ruikq.decar`

The native macOS build bundle id is:

- `com.loon.Loon`

What it does:

- checks every 5 seconds whether `LoonTunnelProvider` is still running
- if the provider has dropped, it reopens the configured Loon app in the background

Files:

- `ensure_loon2_running.sh`: watchdog check script
- `com.hcy.loon2-watchdog.plist`: LaunchAgent definition
- `install_loon2_watchdog.sh`: installs and starts the LaunchAgent

Install:

```sh
cd ~/.config/sketchybar/loon2-watchdog
./install_loon2_watchdog.sh
```

Logs:

- `/tmp/loon2-watchdog.log`
- `/tmp/loon2-watchdog.stdout.log`
- `/tmp/loon2-watchdog.stderr.log`

Notes:

- reopening uses `open -gj -a "<configured loon app>"` to avoid stealing focus as much as possible
- because this is an iPad app running on macOS, background behavior is still controlled by the system
- this watchdog reduces downtime; it does not change the app's own lifecycle model
- default target bundle id is `com.ruikq.decar`
- to target the native macOS build instead, set `LOON_WATCHDOG_BUNDLE_ID=com.loon.Loon`

## Loon 2 Watchdog

This folder contains a lightweight LaunchAgent watchdog for `Loon 2.app` on macOS.

What it does:

- checks every 5 seconds whether `LoonTunnelProvider` is still running
- if the provider has dropped, it reopens `Loon 2` in the background

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

- reopening uses `open -gj -a "Loon 2"` to avoid stealing focus as much as possible
- because this is an iPad app running on macOS, background behavior is still controlled by the system
- this watchdog reduces downtime; it does not change Loon 2's own lifecycle model

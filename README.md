# Clash Gatito

`Clash Gatito` is a cross-platform tray-only controller for Mihomo / Clash
compatible backends.

It is designed for people who want a lightweight desktop controller without a
full Flutter shell. The app lives in the system tray, reads controller settings
from a local config file, and talks to a remote or local Clash-compatible API.

## Features

- Pure tray app for macOS, Linux, and Windows
- Reads `host`, `port`, and `secret` from a local config file
- Auto refreshes backend state and tray menus
- Supports launch at login
- Switches `Rule` / `Global` / `Direct` mode from the tray
- Switches selector proxies from the tray
- Supports group latency testing with cached results
- Opens the config file in your system editor
- Opens the backend web dashboard in your default browser
- Includes direct network reachability checks and IP lookup checks

## Requirements

- A reachable Mihomo / Clash-compatible external controller
- `host`, `port`, and `secret` configured locally

The app can control a backend running on the same machine or on another device
such as a router.

## Config File

The config file is created automatically on the first launch.

- macOS: `~/Library/Application Support/clash-gatito/config.toml`
- Linux: `$XDG_CONFIG_HOME/clash-gatito/config.toml` or `~/.config/clash-gatito/config.toml`
- Windows: `%APPDATA%\clash-gatito\config.toml`

Example:

```toml
host = "127.0.0.1"
port = 9090
secret = "your-secret"
refresh_interval_seconds = 300
launch_at_login = true
```

Notes:

- `host`, `port`, and `secret` are required for backend control.
- `refresh_interval_seconds` is clamped to at least `1`.
- Editing the config file takes effect after the next refresh.

## Tray Menu

The tray menu currently includes:

- Backend summary and refresh interval
- Traffic and expire labels when they are exposed by the backend
- `Mode` switching
- `Proxies` group switching
- `Test Group` latency tests
- `Network -> Run Checks`
- `Refresh`
- `Launch at Login`
- `Open Dashboard`
- `Open Config...`

`Open Dashboard` opens the configured backend UI at
`/ui/zashboard/#/setup?...` in your default browser.

## Network Checks

`Network -> Run Checks` performs direct checks from the local machine.

Current site checks:

- `Baidu`
- `NetEase`
- `GitHub`
- `YouTube`
- `OpenAI`

Current IP providers:

- `IPIP`
- `UpaiYun`
- `ip.sb`
- `IPIFY`

These checks are not routed through the backend controller API. They reflect the
network environment of the machine running `Clash Gatito Tray`.

## Run From Source

```bash
cargo run
```

Build a release binary:

```bash
cargo build --release
```

Release output:

- macOS / Linux: `target/release/clash-gatito`
- Windows: `target\release\clash-gatito.exe`

## macOS App Bundle

Build a native `.app` bundle on macOS:

```bash
./scripts/package_macos_app.sh
```

Output:

- `output/Clash Gatito.app`

Notes:

- The script builds the Rust binary in release mode.
- If `output/AppIcon.icns` already exists, the script uses it directly.
- If `app_icon.png` exists in the project root, it will be used as the app icon.
- Otherwise the script falls back to `tray_icon.png`.
- `LSUIElement` is enabled, so the app runs as a tray-only app without a Dock
  icon.

## Linux Notes

`tray-icon` depends on GTK/AppIndicator on Linux. Typical packages:

- Debian/Ubuntu: `libgtk-3-dev libxdo-dev libappindicator3-dev`
- Arch: `gtk3 xdotool libappindicator-gtk3`

Depending on your desktop environment, additional AppIndicator compatibility
packages may be needed.

## License

This project is licensed under MIT. See [LICENSE](LICENSE).

The tray icon uses Lucide's `earth` icon. Third-party attribution and upstream
license text are listed in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

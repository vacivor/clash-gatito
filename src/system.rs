use std::env;
use std::path::PathBuf;
use std::process::Command;

use anyhow::{Context, Result, anyhow};
#[cfg(target_os = "linux")]
use auto_launch::LinuxLaunchMode;
#[cfg(target_os = "macos")]
use auto_launch::MacOSLaunchMode;
#[cfg(target_os = "windows")]
use auto_launch::WindowsEnableMode;
use auto_launch::{AutoLaunch, AutoLaunchBuilder};

use crate::config::{ensure_config_exists, load_config, save_config};
use crate::constants::{APP_NAME, BUNDLE_ID};
use crate::models::{ActionOutcome, AppConfig};
use crate::tray_helpers::url_encode;

pub fn toggle_launch_at_login() -> Result<ActionOutcome> {
    let mut config = load_config()?;
    config.launch_at_login = !config.launch_at_login;
    save_config(&config)?;
    sync_launch_at_login(&config)?;

    Ok(ActionOutcome {
        status: if config.launch_at_login {
            "Launch at login enabled".to_string()
        } else {
            "Launch at login disabled".to_string()
        },
        trigger_refresh: true,
    })
}

pub fn sync_launch_at_login(config: &AppConfig) -> Result<()> {
    let auto = build_auto_launch()?;
    let enabled = auto.is_enabled().context("check launch-at-login status")?;
    if config.launch_at_login && !enabled {
        auto.enable().context("enable launch at login")?;
    } else if !config.launch_at_login && enabled {
        auto.disable().context("disable launch at login")?;
    }
    Ok(())
}

fn build_auto_launch() -> Result<AutoLaunch> {
    let exe = env::current_exe().context("resolve current executable")?;
    let exe = exe
        .canonicalize()
        .or_else(|_| Ok::<PathBuf, std::io::Error>(exe))?;
    let exe_str = exe.to_string_lossy().to_string();

    let mut builder = AutoLaunchBuilder::new();
    builder.set_app_name(APP_NAME).set_app_path(&exe_str);

    #[cfg(target_os = "linux")]
    builder.set_linux_launch_mode(LinuxLaunchMode::XdgAutostart);
    #[cfg(target_os = "macos")]
    builder
        .set_macos_launch_mode(MacOSLaunchMode::LaunchAgent)
        .set_bundle_identifiers(&[BUNDLE_ID]);
    #[cfg(target_os = "windows")]
    builder.set_windows_enable_mode(WindowsEnableMode::CurrentUser);

    builder.build().context("build auto-launch config")
}

pub fn open_config_file() -> Result<ActionOutcome> {
    let path = ensure_config_exists()?;
    #[cfg(target_os = "macos")]
    let mut command = {
        let mut command = Command::new("open");
        command.arg(&path);
        command
    };
    #[cfg(target_os = "linux")]
    let mut command = {
        let mut command = Command::new("xdg-open");
        command.arg(&path);
        command
    };
    #[cfg(target_os = "windows")]
    let mut command = {
        let mut command = Command::new("cmd");
        command.args(["/C", "start", ""]).arg(&path);
        command
    };

    command
        .status()
        .with_context(|| format!("open {}", path.display()))?;

    Ok(ActionOutcome {
        status: format!("Opened {}", path.display()),
        trigger_refresh: false,
    })
}

pub fn open_dashboard() -> Result<ActionOutcome> {
    let config = load_config()?;
    let url = build_dashboard_url(&config)?;
    #[cfg(target_os = "macos")]
    let mut command = {
        let mut command = Command::new("open");
        command.arg(&url);
        command
    };
    #[cfg(target_os = "linux")]
    let mut command = {
        let mut command = Command::new("xdg-open");
        command.arg(&url);
        command
    };
    #[cfg(target_os = "windows")]
    let mut command = {
        let mut command = Command::new("cmd");
        command.args(["/C", "start", ""]).arg(&url);
        command
    };

    command.status().with_context(|| format!("open {url}"))?;

    Ok(ActionOutcome {
        status: "Opened dashboard".to_string(),
        trigger_refresh: false,
    })
}

fn build_dashboard_url(config: &AppConfig) -> Result<String> {
    if !config.is_complete() {
        return Err(anyhow!("Config incomplete. Fill host, port and secret."));
    }
    let host = url_encode(&config.host);
    let port = config.port.to_string();
    let secret = url_encode(&config.secret);
    Ok(format!(
        "http://{}:{}/ui/zashboard/#/setup?hostname={}&port={}&secret={}",
        config.host, config.port, host, port, secret
    ))
}

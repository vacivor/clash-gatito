use std::env;
use std::fs;
use std::path::PathBuf;

use anyhow::{Context, Result, anyhow};

use crate::models::AppConfig;

pub fn config_path() -> Result<PathBuf> {
    #[cfg(target_os = "macos")]
    {
        return app_support_config_path();
    }
    #[cfg(target_os = "windows")]
    {
        let appdata = env::var("APPDATA").context("APPDATA is not set")?;
        return Ok(PathBuf::from(appdata)
            .join("clash-gatito")
            .join("config.toml"));
    }
    #[cfg(target_os = "linux")]
    {
        if let Ok(config_home) = env::var("XDG_CONFIG_HOME") {
            return Ok(PathBuf::from(config_home)
                .join("clash-gatito")
                .join("config.toml"));
        }
        let home = env::var("HOME").context("HOME is not set")?;
        return Ok(PathBuf::from(home)
            .join(".config")
            .join("clash-gatito")
            .join("config.toml"));
    }
    #[allow(unreachable_code)]
    Err(anyhow!("Unsupported OS"))
}

#[cfg(target_os = "macos")]
fn app_support_config_path() -> Result<PathBuf> {
    let home = env::var("HOME").context("HOME is not set")?;
    Ok(PathBuf::from(home)
        .join("Library")
        .join("Application Support")
        .join("clash-gatito")
        .join("config.toml"))
}

pub fn ensure_config_exists() -> Result<PathBuf> {
    let path = config_path()?;
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).with_context(|| format!("create {}", parent.display()))?;
    }
    if !path.exists() {
        fs::write(&path, render_config(&AppConfig::default()))
            .with_context(|| format!("write {}", path.display()))?;
    }
    Ok(path)
}

pub fn load_config() -> Result<AppConfig> {
    let path = ensure_config_exists()?;
    let content = fs::read_to_string(&path).with_context(|| format!("read {}", path.display()))?;
    Ok(toml::from_str::<AppConfig>(&content)
        .with_context(|| format!("parse {}", path.display()))?
        .normalized())
}

pub fn save_config(config: &AppConfig) -> Result<()> {
    let path = ensure_config_exists()?;
    fs::write(&path, render_config(config)).with_context(|| format!("write {}", path.display()))?;
    Ok(())
}

fn render_config(config: &AppConfig) -> String {
    format!(
        "# Clash Gatito tray configuration\n# Edit this file and click Refresh in the tray.\n\nhost = \"{}\"\nport = {}\nsecret = \"{}\"\nrefresh_interval_seconds = {}\nlaunch_at_login = {}\n",
        escape_toml(&config.host),
        config.port,
        escape_toml(&config.secret),
        config.refresh_interval_seconds.max(1),
        if config.launch_at_login {
            "true"
        } else {
            "false"
        },
    )
}

fn escape_toml(value: &str) -> String {
    value.replace('\\', "\\\\").replace('"', "\\\"")
}

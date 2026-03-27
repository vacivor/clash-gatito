use anyhow::{Result, anyhow};
use serde::{Deserialize, Serialize};

use crate::constants::DEFAULT_REFRESH_SECONDS;

pub fn default_refresh_seconds() -> u64 {
    DEFAULT_REFRESH_SECONDS
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    #[serde(default)]
    pub host: String,
    #[serde(default)]
    pub port: u16,
    #[serde(default)]
    pub secret: String,
    #[serde(default = "default_refresh_seconds")]
    pub refresh_interval_seconds: u64,
    #[serde(default)]
    pub launch_at_login: bool,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            host: String::new(),
            port: 7890,
            secret: String::new(),
            refresh_interval_seconds: DEFAULT_REFRESH_SECONDS,
            launch_at_login: false,
        }
    }
}

impl AppConfig {
    pub fn normalized(mut self) -> Self {
        self.host = self.host.trim().to_string();
        self.secret = self.secret.trim().to_string();
        if self.refresh_interval_seconds == 0 {
            self.refresh_interval_seconds = DEFAULT_REFRESH_SECONDS;
        }
        self
    }

    pub fn backend_label(&self) -> String {
        if self.host.is_empty() || self.port == 0 {
            "Not configured".to_string()
        } else {
            format!("{}:{}", self.host, self.port)
        }
    }

    pub fn is_complete(&self) -> bool {
        !self.host.is_empty() && self.port > 0 && !self.secret.is_empty()
    }

    pub fn base_url(&self) -> Result<String> {
        if !self.is_complete() {
            return Err(anyhow!("Config incomplete"));
        }
        Ok(format!("http://{}:{}", self.host, self.port))
    }
}

#[derive(Debug, Clone, Default)]
pub struct ClashSnapshot {
    pub mode: String,
    pub traffic: Option<String>,
    pub expire: Option<String>,
    pub groups: Vec<ProxyGroup>,
}

#[derive(Debug, Clone)]
pub struct ProxyGroup {
    pub name: String,
    pub selected: Option<String>,
    pub nodes: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct RefreshResult {
    pub config: AppConfig,
    pub snapshot: Option<ClashSnapshot>,
    pub status: String,
    pub error: Option<String>,
}

#[derive(Debug, Clone)]
pub struct ActionOutcome {
    pub status: String,
    pub trigger_refresh: bool,
}

#[derive(Debug, Clone)]
pub struct GroupTestResult {
    pub group: String,
    pub latencies: std::collections::HashMap<String, Option<u64>>,
}

#[derive(Debug, Clone)]
pub struct GroupTestProgress {
    pub group: String,
    pub node: String,
    pub latency: Option<u64>,
}

#[derive(Debug, Clone)]
pub struct NetworkCheckResult {
    pub access: Vec<(&'static str, String)>,
    pub ip_checks: Vec<(&'static str, String)>,
}

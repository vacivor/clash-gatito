use std::collections::HashMap;
use std::time::Duration;

use anyhow::{Context, Result};
use reqwest::blocking::Client;
use reqwest::header::{AUTHORIZATION, CONTENT_TYPE, HeaderMap, HeaderValue};
use serde_json::{Value, json};

use crate::config::load_config;
use crate::constants::{DEFAULT_TEST_TIMEOUT_MS, DEFAULT_TEST_URL};
use crate::models::{ActionOutcome, AppConfig, ClashSnapshot, ProxyGroup, RefreshResult};
use crate::system::sync_launch_at_login;
use crate::tray_helpers::url_encode;

pub fn perform_refresh() -> Result<RefreshResult> {
    let config = load_config()?;
    sync_launch_at_login(&config)?;
    if !config.is_complete() {
        return Ok(RefreshResult {
            config,
            snapshot: None,
            status: "Waiting for configuration".to_string(),
            error: Some("Config incomplete. Fill host, port and secret.".to_string()),
        });
    }

    let snapshot = fetch_snapshot(&config)?;
    Ok(RefreshResult {
        config,
        snapshot: Some(snapshot),
        status: "Clash state refreshed".to_string(),
        error: None,
    })
}

pub fn set_clash_mode(mode: &str) -> Result<ActionOutcome> {
    let config = load_config()?;
    let client = build_client(&config)?;
    let base_url = config.base_url()?;
    client
        .patch(format!("{base_url}/configs"))
        .json(&json!({ "mode": mode }))
        .send()
        .context("patch /configs")?
        .error_for_status()
        .context("status patch /configs")?;

    Ok(ActionOutcome {
        status: format!("Mode switched to {mode}"),
        trigger_refresh: true,
    })
}

pub fn set_clash_proxy(group: &str, node: &str) -> Result<ActionOutcome> {
    let config = load_config()?;
    let client = build_client(&config)?;
    let base_url = config.base_url()?;
    let encoded_group = url_encode(group);
    client
        .put(format!("{base_url}/proxies/{encoded_group}"))
        .json(&json!({ "name": node }))
        .send()
        .context("put /proxies/<group>")?
        .error_for_status()
        .context("status put /proxies/<group>")?;

    Ok(ActionOutcome {
        status: format!("Proxy switched: {group} -> {node}"),
        trigger_refresh: true,
    })
}

pub fn test_proxy_latency(node: &str) -> Result<Option<u64>> {
    let config = load_config()?;
    let client = build_client(&config)?;
    let base_url = config.base_url()?;
    let encoded_node = url_encode(node);
    let timeout = DEFAULT_TEST_TIMEOUT_MS.to_string();
    let response: Value = client
        .get(format!("{base_url}/proxies/{encoded_node}/delay"))
        .query(&[("url", DEFAULT_TEST_URL), ("timeout", timeout.as_str())])
        .send()
        .context("get /proxies/<node>/delay")?
        .error_for_status()
        .context("status get /proxies/<node>/delay")?
        .json()
        .context("parse /proxies/<node>/delay")?;

    Ok(response
        .get("delay")
        .and_then(Value::as_u64)
        .and_then(|ms| if ms == 0 { None } else { Some(ms) }))
}

fn fetch_snapshot(config: &AppConfig) -> Result<ClashSnapshot> {
    let client = build_client(config)?;
    let base_url = config.base_url()?;

    let configs: Value = client
        .get(format!("{base_url}/configs"))
        .send()
        .context("request /configs")?
        .error_for_status()
        .context("status /configs")?
        .json()
        .context("parse /configs")?;

    let proxies: Value = client
        .get(format!("{base_url}/proxies"))
        .send()
        .context("request /proxies")?
        .error_for_status()
        .context("status /proxies")?
        .json()
        .context("parse /proxies")?;

    let mode = configs
        .get("mode")
        .and_then(Value::as_str)
        .unwrap_or("Rule")
        .to_string();
    let proxies_map = proxies
        .get("proxies")
        .and_then(Value::as_object)
        .context("missing proxies object")?;

    let mut groups = Vec::new();
    let mut entries: Vec<_> = proxies_map.iter().collect();
    let traffic = find_special_label(
        proxies_map,
        &[
            "Traffic",
            "剩余流量",
            "Remaining Traffic",
            "Remaining traffic",
        ],
    );
    let expire = find_special_label(
        proxies_map,
        &["Expire", "套餐到期", "到期时间", "Expire Date"],
    );
    let global_order = proxies_map
        .get("GLOBAL")
        .and_then(|value| value.get("all"))
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(Value::as_str)
                .enumerate()
                .map(|(index, name)| (name, index))
                .collect::<HashMap<_, _>>()
        })
        .unwrap_or_default();
    entries.sort_by_key(|(name, _)| {
        global_order
            .get(name.as_str())
            .copied()
            .unwrap_or(usize::MAX)
    });

    for (name, value) in entries {
        let Some(all) = value.get("all").and_then(Value::as_array) else {
            continue;
        };

        let mut nodes = Vec::new();
        for item in all {
            let Some(text) = item.as_str() else {
                continue;
            };
            if !proxies_map.contains_key(text) {
                continue;
            }
            if !nodes.iter().any(|existing| existing == text) {
                nodes.push(text.to_string());
            }
        }
        if !nodes.is_empty() {
            groups.push(ProxyGroup {
                name: name.to_string(),
                selected: value.get("now").and_then(Value::as_str).map(str::to_string),
                nodes,
            });
        }
    }

    Ok(ClashSnapshot {
        mode,
        traffic,
        expire,
        groups,
    })
}

fn find_special_label(
    proxies_map: &serde_json::Map<String, Value>,
    keywords: &[&str],
) -> Option<String> {
    for group_name in ["Proxies", "GLOBAL"] {
        let Some(items) = proxies_map
            .get(group_name)
            .and_then(|value| value.get("all"))
            .and_then(Value::as_array)
        else {
            continue;
        };

        if let Some(label) = items
            .iter()
            .filter_map(Value::as_str)
            .find_map(|item| extract_special_label(item, keywords))
        {
            return Some(label);
        }
    }

    proxies_map
        .values()
        .filter_map(|value| value.get("all"))
        .filter_map(Value::as_array)
        .flat_map(|items| items.iter())
        .filter_map(Value::as_str)
        .find_map(|item| extract_special_label(item, keywords))
}

fn extract_special_label(item: &str, keywords: &[&str]) -> Option<String> {
    let label = item.rsplit('#').next().unwrap_or(item).trim();
    if label.is_empty() {
        return None;
    }

    let label_lower = label.to_lowercase();
    if keywords
        .iter()
        .any(|keyword| label_lower.contains(&keyword.to_lowercase()))
    {
        Some(label.to_string())
    } else {
        None
    }
}

fn build_client(config: &AppConfig) -> Result<Client> {
    let mut headers = HeaderMap::new();
    headers.insert(
        AUTHORIZATION,
        HeaderValue::from_str(&format!("Bearer {}", config.secret))
            .context("invalid secret header")?,
    );
    headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));

    Client::builder()
        .default_headers(headers)
        .timeout(Duration::from_secs(5))
        .build()
        .context("build HTTP client")
}

use std::time::Instant;

use anyhow::{Context, Result};
use reqwest::blocking::Client;
use serde_json::Value;

use crate::models::NetworkCheckResult;

pub fn run_network_checks() -> Result<NetworkCheckResult> {
    let direct_client = Client::builder()
        .timeout(std::time::Duration::from_secs(8))
        .build()
        .context("build direct check client")?;

    let access = vec![
        ("Baidu", check_site(&direct_client, "https://www.baidu.com")),
        (
            "NetEase",
            check_site(&direct_client, "https://music.163.com"),
        ),
        ("GitHub", check_site(&direct_client, "https://github.com")),
        (
            "YouTube",
            check_site(&direct_client, "https://www.youtube.com"),
        ),
        (
            "OpenAI",
            check_site(&direct_client, "https://chat.openai.com"),
        ),
    ];

    let ip_checks = vec![
        (
            "IPIP",
            fetch_ip_label(&direct_client, "https://myip.ipip.net")
                .unwrap_or_else(|error| format!("Failed ({error})")),
        ),
        (
            "UpaiYun",
            fetch_upaiyun_label(&direct_client, "https://pubstatic.b0.upaiyun.com/?_upnode")
                .unwrap_or_else(|error| format!("Failed ({error})")),
        ),
        (
            "ip.sb",
            fetch_ip_sb_label(&direct_client, "https://api.ip.sb/geoip")
                .unwrap_or_else(|error| format!("Failed ({error})")),
        ),
        (
            "IPIFY",
            fetch_ip_label(&direct_client, "https://api.ipify.org")
                .unwrap_or_else(|error| format!("Failed ({error})")),
        ),
    ];

    Ok(NetworkCheckResult { access, ip_checks })
}

fn check_site(client: &Client, url: &str) -> String {
    let start = Instant::now();
    match client.get(url).send() {
        Ok(response) if response.status().is_success() => {
            format!("{}ms", start.elapsed().as_millis())
        }
        Ok(response) => format!("HTTP {}", response.status().as_u16()),
        Err(error) => format!("Failed ({error})"),
    }
}

fn fetch_ip_label(client: &Client, url: &str) -> Result<String> {
    let response = client
        .get(url)
        .send()
        .context("request ip check")?
        .error_for_status()
        .context("status ip check")?;
    let text = response.text().context("read ip check body")?;

    if let Ok(value) = serde_json::from_str::<Value>(&text) {
        let ip = value.get("ip").and_then(Value::as_str).unwrap_or("unknown");
        let country = value
            .get("country")
            .and_then(Value::as_str)
            .or_else(|| value.get("country_code").and_then(Value::as_str))
            .unwrap_or("unknown");
        let city = value.get("city").and_then(Value::as_str).unwrap_or("");

        let mut label = format!("{ip} [{country}]");
        if !city.is_empty() {
            label.push(' ');
            label.push_str(city);
        }
        return Ok(label);
    }

    Ok(text.trim().to_string())
}

fn fetch_upaiyun_label(client: &Client, url: &str) -> Result<String> {
    let value: Value = client
        .get(url)
        .send()
        .context("request upaiyun ip check")?
        .error_for_status()
        .context("status upaiyun ip check")?
        .json()
        .context("parse upaiyun ip check")?;

    let ip = value
        .get("remote_addr")
        .and_then(Value::as_str)
        .or_else(|| value.get("addr").and_then(Value::as_str))
        .unwrap_or("unknown");
    let location = value
        .get("remote_addr_location")
        .or_else(|| value.get("addr_location"));
    let country = location
        .and_then(|loc| loc.get("country"))
        .and_then(Value::as_str)
        .unwrap_or("");
    let province = location
        .and_then(|loc| loc.get("province"))
        .and_then(Value::as_str)
        .unwrap_or("");
    let city = location
        .and_then(|loc| loc.get("city"))
        .and_then(Value::as_str)
        .unwrap_or("");
    let isp = location
        .and_then(|loc| loc.get("isp"))
        .and_then(Value::as_str)
        .unwrap_or("");

    let location_text = [country, province, city, isp]
        .into_iter()
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join(" ");

    if location_text.is_empty() {
        Ok(ip.to_string())
    } else {
        Ok(format!("{ip} [{location_text}]"))
    }
}

fn fetch_ip_sb_label(client: &Client, url: &str) -> Result<String> {
    let value: Value = client
        .get(url)
        .send()
        .context("request ip.sb check")?
        .error_for_status()
        .context("status ip.sb check")?
        .json()
        .context("parse ip.sb check")?;

    let ip = value.get("ip").and_then(Value::as_str).unwrap_or("unknown");
    let country_code = value
        .get("country_code")
        .and_then(Value::as_str)
        .unwrap_or("");
    let country = value.get("country").and_then(Value::as_str).unwrap_or("");
    let city = value.get("city").and_then(Value::as_str).unwrap_or("");
    let isp = value
        .get("isp")
        .and_then(Value::as_str)
        .or_else(|| value.get("organization").and_then(Value::as_str))
        .or_else(|| value.get("asn_organization").and_then(Value::as_str))
        .unwrap_or("");

    let location_text = [country_code, country, city]
        .into_iter()
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join(" ");

    if isp.is_empty() && location_text.is_empty() {
        Ok(ip.to_string())
    } else if isp.is_empty() {
        Ok(format!("{ip} [{location_text}]"))
    } else if location_text.is_empty() {
        Ok(format!("{ip} [{isp}]"))
    } else {
        Ok(format!("{ip} [{location_text}] {isp}"))
    }
}

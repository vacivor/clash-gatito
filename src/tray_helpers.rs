use std::env;
use std::fs::File;
use std::io::BufReader;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result, anyhow};
use tray_icon::{Icon, TrayIcon, TrayIconBuilder, menu::Menu};

use crate::constants::{APP_ID_PREFIX, APP_NAME};

pub fn build_tray(menu: Menu) -> Result<TrayIcon> {
    let icon = build_icon()?;
    let builder = TrayIconBuilder::new()
        .with_menu(Box::new(menu))
        .with_tooltip(APP_NAME)
        .with_icon(icon);
    #[cfg(target_os = "macos")]
    let builder = builder.with_icon_as_template(true);
    builder.build().context("build tray icon")
}

fn build_icon() -> Result<Icon> {
    let path = resolve_tray_icon_path()?;
    let file = File::open(&path).with_context(|| format!("open {}", path.display()))?;
    let decoder = png::Decoder::new(BufReader::new(file));
    let mut reader = decoder
        .read_info()
        .with_context(|| format!("read png info from {}", path.display()))?;
    let mut buf = vec![0; reader.output_buffer_size()];
    let info = reader
        .next_frame(&mut buf)
        .with_context(|| format!("decode png frame from {}", path.display()))?;

    let bytes = &buf[..info.buffer_size()];
    let mut rgba = match info.color_type {
        png::ColorType::Rgba => bytes.to_vec(),
        png::ColorType::Rgb => {
            let mut rgba = Vec::with_capacity((info.width * info.height * 4) as usize);
            for chunk in bytes.chunks_exact(3) {
                rgba.extend_from_slice(&[chunk[0], chunk[1], chunk[2], 255]);
            }
            rgba
        }
        png::ColorType::GrayscaleAlpha => {
            let mut rgba = Vec::with_capacity((info.width * info.height * 4) as usize);
            for chunk in bytes.chunks_exact(2) {
                rgba.extend_from_slice(&[chunk[0], chunk[0], chunk[0], chunk[1]]);
            }
            rgba
        }
        png::ColorType::Grayscale => {
            let mut rgba = Vec::with_capacity((info.width * info.height * 4) as usize);
            for gray in bytes {
                rgba.extend_from_slice(&[*gray, *gray, *gray, 255]);
            }
            rgba
        }
        png::ColorType::Indexed => {
            return Err(anyhow!(
                "indexed-color PNG is not supported for tray icon: {}",
                path.display()
            ));
        }
    };

    tint_linux_tray_icon(&mut rgba);

    Icon::from_rgba(rgba, info.width, info.height).context("create tray icon from png")
}

#[cfg(target_os = "linux")]
fn tint_linux_tray_icon(rgba: &mut [u8]) {
    for pixel in rgba.chunks_exact_mut(4) {
        if pixel[3] > 0 {
            pixel[0] = 255;
            pixel[1] = 255;
            pixel[2] = 255;
        }
    }
}

#[cfg(not(target_os = "linux"))]
fn tint_linux_tray_icon(_rgba: &mut [u8]) {}

fn resolve_tray_icon_path() -> Result<PathBuf> {
    let mut candidates = Vec::new();

    if let Ok(current_exe) = env::current_exe() {
        if let Some(exe_dir) = current_exe.parent() {
            candidates.push(exe_dir.join("tray_icon.png"));

            #[cfg(target_os = "macos")]
            if let Some(contents_dir) = exe_dir.parent() {
                candidates.push(contents_dir.join("Resources").join("tray_icon.png"));
            }
        }
    }

    #[cfg(target_os = "linux")]
    candidates.push(
        Path::new("/usr/share")
            .join(APP_ID_PREFIX)
            .join("tray_icon.png"),
    );
    #[cfg(target_os = "linux")]
    candidates.push(
        Path::new("/app/share")
            .join(APP_ID_PREFIX)
            .join("tray_icon.png"),
    );

    candidates.push(Path::new(env!("CARGO_MANIFEST_DIR")).join("tray_icon.png"));

    candidates
        .into_iter()
        .find(|path| path.is_file())
        .ok_or_else(|| anyhow!("could not locate tray_icon.png in runtime search paths"))
}

pub fn clear_menu(menu: &Menu) {
    while !menu.items().is_empty() {
        let _ = menu.remove_at(0);
    }
}

pub fn parse_proxy_id(app_id_prefix: &str, id: &str) -> Option<(String, String)> {
    let prefix = format!("{app_id_prefix}:proxy:");
    let rest = id.strip_prefix(&prefix)?;
    let (group, node) = rest.split_once(':')?;
    Some((decode_component(group), decode_component(node)))
}

pub fn parse_test_group_id(app_id_prefix: &str, id: &str) -> Option<String> {
    let prefix = format!("{app_id_prefix}:test-group:");
    id.strip_prefix(&prefix).map(decode_component)
}

pub fn encode_component(value: &str) -> String {
    let mut output = String::new();
    for byte in value.bytes() {
        if byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_' | b'.' | b'~') {
            output.push(byte as char);
        } else {
            output.push('%');
            output.push_str(&format!("{byte:02X}"));
        }
    }
    output
}

fn decode_component(value: &str) -> String {
    let bytes = value.as_bytes();
    let mut output = Vec::with_capacity(bytes.len());
    let mut index = 0;
    while index < bytes.len() {
        if bytes[index] == b'%' && index + 2 < bytes.len() {
            let hex = &value[index + 1..index + 3];
            if let Ok(decoded) = u8::from_str_radix(hex, 16) {
                output.push(decoded);
                index += 3;
                continue;
            }
        }
        output.push(bytes[index]);
        index += 1;
    }
    String::from_utf8_lossy(&output).into_owned()
}

pub fn url_encode(value: &str) -> String {
    encode_component(value)
}

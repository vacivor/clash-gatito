#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Clash Gatito"
BIN_NAME="clash-gatito"
EXECUTABLE_NAME="Clash Gatito"
BUNDLE_ID="io.vacivor.clash-gatito"
APP_DIR="$ROOT_DIR/output/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/output/app.iconset"
ICON_SOURCE="$ROOT_DIR/app_icon.png"
SVG_ICON_SOURCE="$ROOT_DIR/app_icon.svg"
GENERATED_ICON_SOURCE="$ROOT_DIR/output/app_icon.png"
QLMANAGE_ICON_SOURCE="$ROOT_DIR/output/app_icon.svg.png"
PREBUILT_ICNS_SOURCE="$ROOT_DIR/output/AppIcon.icns"
if [[ ! -f "$ICON_SOURCE" ]]; then
  if [[ -f "$SVG_ICON_SOURCE" ]]; then
    qlmanage -t -s 1024 -o "$ROOT_DIR/output" "$SVG_ICON_SOURCE" >/dev/null
    if [[ -f "$QLMANAGE_ICON_SOURCE" ]]; then
      mv "$QLMANAGE_ICON_SOURCE" "$GENERATED_ICON_SOURCE"
      ICON_SOURCE="$GENERATED_ICON_SOURCE"
    fi
  fi
fi
if [[ ! -f "$ICON_SOURCE" ]]; then
  ICON_SOURCE="$ROOT_DIR/tray_icon.png"
fi

VERSION="$(awk -F ' = ' '/^version = / { gsub(/"/, "", $2); print $2; exit }' "$ROOT_DIR/Cargo.toml")"

cd "$ROOT_DIR"
cargo build --release

rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/target/release/$BIN_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

ICON_NAME=""
if [[ -f "$PREBUILT_ICNS_SOURCE" ]]; then
  cp "$PREBUILT_ICNS_SOURCE" "$RESOURCES_DIR/AppIcon.icns"
  ICON_NAME="AppIcon.icns"
elif [[ -f "$ICON_SOURCE" ]]; then
  mkdir -p "$ICONSET_DIR"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    if [[ "$size" -eq 512 ]]; then
      cp "$ICON_SOURCE" "$ICONSET_DIR/icon_${size}x${size}@2x.png"
    else
      sips -z "$double_size" "$double_size" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
    fi
  done
  iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
  ICON_NAME="AppIcon.icns"
  rm -rf "$ICONSET_DIR"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${EXECUTABLE_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>11.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
PLIST

if [[ -n "$ICON_NAME" ]]; then
cat >> "$CONTENTS_DIR/Info.plist" <<PLIST
  <key>CFBundleIconFile</key>
  <string>${ICON_NAME}</string>
PLIST
fi

cat >> "$CONTENTS_DIR/Info.plist" <<PLIST
</dict>
</plist>
PLIST

echo "Built app bundle: $APP_DIR"

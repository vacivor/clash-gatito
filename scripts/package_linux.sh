#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_NAME="clash-gatito"
APP_NAME="Clash Gatito"
SUMMARY="Tray-only controller for Mihomo / Clash compatible backends"
VERSION="$(awk -F ' = ' '/^version = / { gsub(/"/, "", $2); print $2; exit }' "$ROOT_DIR/Cargo.toml")"
RELEASE="${RELEASE:-1}"
MAINTAINER="${MAINTAINER:-Vacivor}"
PACKAGE_ARCH="${PACKAGE_ARCH:-}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output/linux}"
BUILD_DIR="$OUTPUT_DIR/build"
BIN_PATH="$ROOT_DIR/target/release/$PACKAGE_NAME"
ICON_SOURCE="$ROOT_DIR/app_icon.png"
SVG_ICON_SOURCE="$ROOT_DIR/app_icon.svg"
TRAY_ICON_SOURCE="$ROOT_DIR/tray_icon.png"

usage() {
  cat <<USAGE
Usage: $0 [deb] [rpm] [--no-build]

Build Linux packages for $APP_NAME.

Arguments:
  deb         Build only the .deb package
  rpm         Build only the .rpm package
  --no-build  Reuse target/release/$PACKAGE_NAME instead of running cargo build
  -h, --help  Show this help

Environment:
  RELEASE     Package release number, default: 1
  MAINTAINER  Debian maintainer field, default: Vacivor
  PACKAGE_ARCH Package architecture: amd64 or aarch64, default: host arch
  OUTPUT_DIR  Package output directory, default: output/linux
USAGE
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

normalize_arch() {
  case "$1" in
    x86_64 | amd64) echo "amd64" ;;
    aarch64 | arm64) echo "aarch64" ;;
    *)
      echo "error: unsupported Linux package architecture: $1" >&2
      echo "supported architectures: amd64, aarch64" >&2
      exit 1
      ;;
  esac
}

host_arch() {
  if [[ -n "$PACKAGE_ARCH" ]]; then
    normalize_arch "$PACKAGE_ARCH"
    return
  fi

  normalize_arch "$(uname -m)"
}

deb_arch() {
  local arch="$1"
  case "$arch" in
    amd64) echo "amd64" ;;
    aarch64) echo "arm64" ;;
    *)
      echo "error: unsupported deb architecture: $arch" >&2
      exit 1
      ;;
  esac
}

rpm_arch() {
  local arch="$1"
  case "$arch" in
    amd64) echo "x86_64" ;;
    aarch64) echo "aarch64" ;;
    *)
      echo "error: unsupported rpm architecture: $arch" >&2
      exit 1
      ;;
  esac
}

prepare_staging() {
  local staging_dir="$1"
  rm -rf "$staging_dir"
  mkdir -p \
    "$staging_dir/usr/bin" \
    "$staging_dir/usr/share/applications" \
    "$staging_dir/usr/share/icons/hicolor/1024x1024/apps" \
    "$staging_dir/usr/share/icons/hicolor/scalable/apps" \
    "$staging_dir/usr/share/pixmaps" \
    "$staging_dir/usr/share/$PACKAGE_NAME" \
    "$staging_dir/usr/share/doc/$PACKAGE_NAME"

  install -m 755 "$BIN_PATH" "$staging_dir/usr/bin/$PACKAGE_NAME"
  install -m 644 "$TRAY_ICON_SOURCE" "$staging_dir/usr/share/$PACKAGE_NAME/tray_icon.png"

  if [[ -f "$ICON_SOURCE" ]]; then
    install -m 644 "$ICON_SOURCE" "$staging_dir/usr/share/icons/hicolor/1024x1024/apps/$PACKAGE_NAME.png"
    install -m 644 "$ICON_SOURCE" "$staging_dir/usr/share/pixmaps/$PACKAGE_NAME.png"
    install -m 644 "$ICON_SOURCE" "$staging_dir/usr/share/$PACKAGE_NAME/app_icon.png"
  else
    install -m 644 "$TRAY_ICON_SOURCE" "$staging_dir/usr/share/icons/hicolor/1024x1024/apps/$PACKAGE_NAME.png"
    install -m 644 "$TRAY_ICON_SOURCE" "$staging_dir/usr/share/pixmaps/$PACKAGE_NAME.png"
    install -m 644 "$TRAY_ICON_SOURCE" "$staging_dir/usr/share/$PACKAGE_NAME/app_icon.png"
  fi

  if [[ -f "$SVG_ICON_SOURCE" ]]; then
    install -m 644 "$SVG_ICON_SOURCE" "$staging_dir/usr/share/icons/hicolor/scalable/apps/$PACKAGE_NAME.svg"
  fi

  install -m 644 "$ROOT_DIR/LICENSE" "$staging_dir/usr/share/doc/$PACKAGE_NAME/LICENSE"
  install -m 644 "$ROOT_DIR/README.md" "$staging_dir/usr/share/doc/$PACKAGE_NAME/README.md"

  cat > "$staging_dir/usr/share/applications/$PACKAGE_NAME.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$APP_NAME
Comment=$SUMMARY
Exec=/usr/bin/$PACKAGE_NAME
Icon=$PACKAGE_NAME
Terminal=false
Categories=Network;
StartupNotify=false
DESKTOP
}

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "error: missing required file: $1" >&2
    exit 1
  fi
}

build_deb() {
  if ! command_exists dpkg-deb; then
    echo "error: dpkg-deb is required to build .deb packages" >&2
    exit 1
  fi

  local arch
  local package_arch
  local package_root
  local deb_path
  package_arch="$(host_arch)"
  arch="$(deb_arch "$package_arch")"
  package_root="$BUILD_DIR/deb/${PACKAGE_NAME}_${VERSION}-${RELEASE}_${arch}"
  deb_path="$OUTPUT_DIR/${PACKAGE_NAME}_${VERSION}-${RELEASE}_${arch}.deb"

  prepare_staging "$package_root"
  mkdir -p "$package_root/DEBIAN"

  cat > "$package_root/DEBIAN/control" <<CONTROL
Package: $PACKAGE_NAME
Version: $VERSION-$RELEASE
Section: net
Priority: optional
Architecture: $arch
Maintainer: $MAINTAINER
Depends: ca-certificates, xdg-utils, libgtk-3-0, libayatana-appindicator3-1, libwayland-client0, libxkbcommon0
Description: $SUMMARY
 Clash Gatito is a lightweight desktop tray app for controlling
 Mihomo / Clash-compatible external controllers.
CONTROL

  cat > "$package_root/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi
POSTINST
  chmod 755 "$package_root/DEBIAN/postinst"

  cat > "$package_root/DEBIAN/postrm" <<'POSTRM'
#!/bin/sh
set -e
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi
POSTRM
  chmod 755 "$package_root/DEBIAN/postrm"

  dpkg-deb --build --root-owner-group "$package_root" "$deb_path"
  echo "Built deb package: $deb_path"
}

build_rpm() {
  if ! command_exists rpmbuild; then
    echo "error: rpmbuild is required to build .rpm packages" >&2
    exit 1
  fi

  local arch
  local package_arch
  local rpm_topdir
  local staging_dir
  local spec_file
  package_arch="$(host_arch)"
  arch="$(rpm_arch "$package_arch")"
  rpm_topdir="$BUILD_DIR/rpm"
  staging_dir="$BUILD_DIR/rpm-staging"
  spec_file="$rpm_topdir/SPECS/$PACKAGE_NAME.spec"

  rm -rf "$rpm_topdir" "$staging_dir"
  mkdir -p "$rpm_topdir/BUILD" "$rpm_topdir/BUILDROOT" "$rpm_topdir/RPMS" "$rpm_topdir/SOURCES" "$rpm_topdir/SPECS" "$rpm_topdir/SRPMS"
  prepare_staging "$staging_dir"

  local svg_files_entry=""
  if [[ -f "$SVG_ICON_SOURCE" ]]; then
    svg_files_entry="/usr/share/icons/hicolor/scalable/apps/$PACKAGE_NAME.svg"
  fi

  cat > "$spec_file" <<SPEC
%global debug_package %{nil}

Name:           $PACKAGE_NAME
Version:        $VERSION
Release:        $RELEASE%{?dist}
Summary:        $SUMMARY
License:        MIT
URL:            https://github.com/vacivor/clash-gatito

Requires:       ca-certificates
Requires:       xdg-utils
Requires:       gtk3
Requires:       libayatana-appindicator-gtk3
Requires:       libwayland-client
Requires:       libxkbcommon
Requires:       hicolor-icon-theme

%description
Clash Gatito is a lightweight desktop tray app for controlling
Mihomo / Clash-compatible external controllers.

%prep

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a "$staging_dir/." %{buildroot}/

%post
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi

%postun
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi

%files
%license /usr/share/doc/$PACKAGE_NAME/LICENSE
%doc /usr/share/doc/$PACKAGE_NAME/README.md
/usr/bin/$PACKAGE_NAME
/usr/share/applications/$PACKAGE_NAME.desktop
/usr/share/icons/hicolor/1024x1024/apps/$PACKAGE_NAME.png
$svg_files_entry
/usr/share/pixmaps/$PACKAGE_NAME.png
/usr/share/$PACKAGE_NAME/app_icon.png
/usr/share/$PACKAGE_NAME/tray_icon.png
SPEC

  rpmbuild --define "_topdir $rpm_topdir" --target "$arch" -bb "$spec_file"
  find "$rpm_topdir/RPMS" -type f -name "*.rpm" -exec cp {} "$OUTPUT_DIR/" \;
  find "$OUTPUT_DIR" -maxdepth 1 -type f -name "${PACKAGE_NAME}-${VERSION}-${RELEASE}*.rpm" -print
}

formats=()
build_release=1

for arg in "$@"; do
  case "$arg" in
    deb | --deb)
      formats+=("deb")
      ;;
    rpm | --rpm)
      formats+=("rpm")
      ;;
    --no-build)
      build_release=0
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ${#formats[@]} -eq 0 ]]; then
  formats=("deb" "rpm")
fi

cd "$ROOT_DIR"
mkdir -p "$OUTPUT_DIR"
require_file "$TRAY_ICON_SOURCE"
require_file "$ROOT_DIR/LICENSE"
require_file "$ROOT_DIR/README.md"

if [[ "$build_release" -eq 1 ]]; then
  cargo build --release
elif [[ ! -x "$BIN_PATH" ]]; then
  echo "error: missing release binary: $BIN_PATH" >&2
  exit 1
fi

for format in "${formats[@]}"; do
  case "$format" in
    deb) build_deb ;;
    rpm) build_rpm ;;
  esac
done

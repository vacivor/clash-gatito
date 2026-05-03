PACKAGE_NAME := clash-gatito
APP_NAME := Clash Gatito
VERSION = $(shell awk -F ' = ' '/^version = / { gsub(/"/, "", $$2); print $$2; exit }' Cargo.toml)
DIST_ARCH ?= $(shell uname -m)
OUTPUT_DIR := output
LINUX_OUTPUT_DIR := $(OUTPUT_DIR)/linux
WINDOWS_OUTPUT_DIR := $(OUTPUT_DIR)/windows
LINUX_DIST_DIR := $(LINUX_OUTPUT_DIR)/$(PACKAGE_NAME)-$(VERSION)-linux-$(DIST_ARCH)

.PHONY: build-release package-linux package-linux-tar package-macos package-macos-zip package-macos-dmg package-windows-zip ci-install-rust ci-install-linux-deps ci-linux-packages ci-windows-package ci-flatpak-prep

build-release:
	cargo build --release --locked

package-linux: build-release
	PACKAGE_ARCH="$(DIST_ARCH)" ./scripts/package_linux.sh deb rpm --no-build

package-linux-tar: build-release
	mkdir -p "$(LINUX_OUTPUT_DIR)"
	rm -rf "$(LINUX_DIST_DIR)"
	mkdir -p "$(LINUX_DIST_DIR)"
	install -m 755 target/release/$(PACKAGE_NAME) "$(LINUX_DIST_DIR)/$(PACKAGE_NAME)"
	install -m 644 tray_icon.png "$(LINUX_DIST_DIR)/tray_icon.png"
	install -m 644 app_icon.png "$(LINUX_DIST_DIR)/app_icon.png"
	install -m 644 LICENSE "$(LINUX_DIST_DIR)/LICENSE"
	install -m 644 README.md "$(LINUX_DIST_DIR)/README.md"
	tar -C "$(LINUX_OUTPUT_DIR)" -czf "$(LINUX_DIST_DIR).tar.gz" "$(notdir $(LINUX_DIST_DIR))"

package-macos: build-release
	./scripts/package_macos_app.sh --no-build

package-macos-zip: package-macos
	ditto -c -k --keepParent "$(OUTPUT_DIR)/$(APP_NAME).app" "$(OUTPUT_DIR)/$(PACKAGE_NAME)-$(VERSION)-macos-$(DIST_ARCH).app.zip"

package-macos-dmg: package-macos
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(OUTPUT_DIR)/$(APP_NAME).app" -ov -format UDZO "$(OUTPUT_DIR)/$(PACKAGE_NAME)-$(VERSION)-macos-$(DIST_ARCH).dmg"

package-windows-zip: build-release
	pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/package_windows_zip.ps1 -DistArch "$(DIST_ARCH)"

ci-install-rust:
	rustup toolchain install stable --profile minimal
	rustup default stable

ci-install-linux-deps:
	sudo apt-get update
	sudo apt-get install -y pkg-config libglib2.0-dev libgtk-3-dev rpm desktop-file-utils hicolor-icon-theme
	sudo apt-get install -y libayatana-appindicator3-dev || sudo apt-get install -y libappindicator3-dev

ci-linux-packages: package-linux package-linux-tar

ci-windows-package: package-windows-zip

ci-flatpak-prep:
	mkdir -p .cargo
	cargo vendor vendor > .cargo/config.toml
	rm -rf shared-modules
	git clone --depth 1 https://github.com/flathub/shared-modules.git shared-modules

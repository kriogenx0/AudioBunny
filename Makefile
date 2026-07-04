APP_NAME       := AudioBunny
MACOS_DIR      := macos
WEB_DIR        := web

DEBUG_BIN      := $(MACOS_DIR)/.build/debug/$(APP_NAME)
RELEASE_BIN    := $(MACOS_DIR)/.build/release/$(APP_NAME)
DEBUG_BUNDLE   := $(MACOS_DIR)/.build/debug/$(APP_NAME).app
RELEASE_BUNDLE := $(MACOS_DIR)/.build/release/$(APP_NAME).app
INSTALL_PATH   := /Applications/$(APP_NAME).app

.PHONY: all dev build setup clean open close install uninstall reinstall \
        web-up web-down web-logs help
.DEFAULT_GOAL := all

# ── Default ───────────────────────────────────────────────────────────────────

all: setup dev

# ── Development ───────────────────────────────────────────────────────────────

setup:
	@echo "▸ Starting web stack…"
	docker compose -f $(WEB_DIR)/docker-compose.yml up -d --build

dev:
	@rm -rf $(DEBUG_BUNDLE)
	@echo "▸ Building $(APP_NAME) (debug)…"
	cd $(MACOS_DIR) && swift build -c debug
	@mkdir -p $(DEBUG_BUNDLE)/Contents/MacOS
	@cp $(DEBUG_BIN) $(DEBUG_BUNDLE)/Contents/MacOS/$(APP_NAME)
	@cp $(MACOS_DIR)/Info.plist $(DEBUG_BUNDLE)/Contents/Info.plist
	open $(DEBUG_BUNDLE)

# ── Production ────────────────────────────────────────────────────────────────

build:
	@echo "▸ Building $(APP_NAME) (release)…"
	cd $(MACOS_DIR) && swift build -c release
	@mkdir -p $(RELEASE_BUNDLE)/Contents/MacOS
	@cp $(RELEASE_BIN) $(RELEASE_BUNDLE)/Contents/MacOS/$(APP_NAME)
	@cp $(MACOS_DIR)/Info.plist $(RELEASE_BUNDLE)/Contents/Info.plist

open: build
	open $(RELEASE_BUNDLE)

close:
	-killall "$(APP_NAME)" 2>/dev/null

# ── Install ───────────────────────────────────────────────────────────────────

install: build
	@cp -R $(RELEASE_BUNDLE) $(INSTALL_PATH)
	@echo "▸ Installed to $(INSTALL_PATH)"
	open $(INSTALL_PATH)

uninstall: close
	@rm -rf $(INSTALL_PATH)
	@echo "▸ Uninstalled $(APP_NAME)"

reinstall: uninstall install

# ── Cleanup ───────────────────────────────────────────────────────────────────

clean:
	@rm -rf $(MACOS_DIR)/.build
	@echo "▸ Cleaned build artifacts"

# ── Web (Docker) ──────────────────────────────────────────────────────────────

web-up:
	docker compose -f $(WEB_DIR)/docker-compose.yml up -d --build

web-down:
	docker compose -f $(WEB_DIR)/docker-compose.yml down

web-logs:
	docker compose -f $(WEB_DIR)/docker-compose.yml logs -f

# ── Help ──────────────────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "  Development"
	@echo "    make              Build debug + start web stack + open app  (= make all)"
	@echo "    make dev          Build debug, delete old bundle, open app"
	@echo "    make setup        Start web stack in Docker"
	@echo ""
	@echo "  Production"
	@echo "    make build        Build release bundle"
	@echo "    make open         Build release + open"
	@echo "    make close        Kill the running app"
	@echo ""
	@echo "  Install"
	@echo "    make install      Build release + copy to /Applications + open"
	@echo "    make uninstall    Kill app + remove from /Applications"
	@echo "    make reinstall    uninstall + install"
	@echo ""
	@echo "  Cleanup"
	@echo "    make clean        Remove all build artifacts"
	@echo ""
	@echo "  Web"
	@echo "    make web-up       Start Docker web stack"
	@echo "    make web-down     Stop Docker web stack"
	@echo "    make web-logs     Tail Docker logs"
	@echo ""

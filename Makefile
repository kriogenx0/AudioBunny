APP_NAME       := AudioBunny
MACOS_DIR      := macos
WEB_DIR        := web

DEBUG_BIN      := $(MACOS_DIR)/.build/debug/$(APP_NAME)
RELEASE_BIN    := $(MACOS_DIR)/.build/release/$(APP_NAME)
DEBUG_BUNDLE   := $(MACOS_DIR)/.build/debug/$(APP_NAME).app
RELEASE_BUNDLE := $(MACOS_DIR)/.build/release/$(APP_NAME).app
INSTALL_PATH   := /Applications/$(APP_NAME).app

# VST2Prober is built universal (arm64 + x86_64) so it can dlopen Intel-only
# VST2 plugins under Rosetta as well as native arm64 ones — see PluginManager's
# VST2 category probing.
VST2PROBER_DEBUG   := $(MACOS_DIR)/.build/apple/Products/Debug/VST2Prober
VST2PROBER_RELEASE := $(MACOS_DIR)/.build/apple/Products/Release/VST2Prober

.PHONY: all dev build setup clean open close install uninstall reinstall \
        test web-up web-down web-logs help
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
	@echo "▸ Building VST2Prober (universal)…"
	cd $(MACOS_DIR) && swift build -c debug --arch arm64 --arch x86_64 --product VST2Prober
	@mkdir -p $(DEBUG_BUNDLE)/Contents/MacOS $(DEBUG_BUNDLE)/Contents/Resources
	@cp $(DEBUG_BIN) $(DEBUG_BUNDLE)/Contents/MacOS/$(APP_NAME)
	@cp $(VST2PROBER_DEBUG) $(DEBUG_BUNDLE)/Contents/MacOS/VST2Prober
	@cp $(MACOS_DIR)/Info.plist $(DEBUG_BUNDLE)/Contents/Info.plist
	@cp $(MACOS_DIR)/AppIcon.icns $(DEBUG_BUNDLE)/Contents/Resources/AppIcon.icns
	open $(DEBUG_BUNDLE)

# ── Production ────────────────────────────────────────────────────────────────

build:
	@echo "▸ Building $(APP_NAME) (release)…"
	cd $(MACOS_DIR) && swift build -c release
	@echo "▸ Building VST2Prober (universal)…"
	cd $(MACOS_DIR) && swift build -c release --arch arm64 --arch x86_64 --product VST2Prober
	@mkdir -p $(RELEASE_BUNDLE)/Contents/MacOS $(RELEASE_BUNDLE)/Contents/Resources
	@cp $(RELEASE_BIN) $(RELEASE_BUNDLE)/Contents/MacOS/$(APP_NAME)
	@cp $(VST2PROBER_RELEASE) $(RELEASE_BUNDLE)/Contents/MacOS/VST2Prober
	@cp $(MACOS_DIR)/Info.plist $(RELEASE_BUNDLE)/Contents/Info.plist
	@cp $(MACOS_DIR)/AppIcon.icns $(RELEASE_BUNDLE)/Contents/Resources/AppIcon.icns

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

# ── Testing ───────────────────────────────────────────────────────────────────

test:
	@echo "▸ Building $(APP_NAME) (debug)…"
	cd $(MACOS_DIR) && swift build -c debug
	@echo "▸ Running unit tests…"
	cd $(MACOS_DIR) && swift test
	@echo "▸ Running launch stress test…"
	$(MACOS_DIR)/scripts/stress_test.sh

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
	@echo "  Testing"
	@echo "    make test         Build + unit tests + launch stress test"
	@echo ""
	@echo "  Cleanup"
	@echo "    make clean        Remove all build artifacts"
	@echo ""
	@echo "  Web"
	@echo "    make web-up       Start Docker web stack"
	@echo "    make web-down     Stop Docker web stack"
	@echo "    make web-logs     Tail Docker logs"
	@echo ""

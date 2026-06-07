MACOS_DIR  := macos
WEB_DIR    := web
APP_BIN    := $(MACOS_DIR)/.build/debug/AudioBunny
APP_BUNDLE := $(MACOS_DIR)/.build/debug/AudioBunny.app

.PHONY: dev dev-down macos-build macos-bundle macos-run web-up web-down web-logs help

# ── Default: build + run everything ──────────────────────────────────────────

dev: macos-bundle web-up
	@echo ""
	@echo "  Web app → http://localhost:5173"
	@echo "  API     → http://localhost:3000"
	@echo ""
	@echo "  'make dev-down' stops Docker."
	@echo ""
	open $(APP_BUNDLE)

dev-down: web-down

# ── macOS ─────────────────────────────────────────────────────────────────────

macos-build:
	@echo "▸ Building macOS app…"
	cd $(MACOS_DIR) && swift build -c debug

# Wrap the SPM binary in a minimal .app bundle so 'open' works properly
# (Dock icon, Cmd+Tab, window focus, etc.)
macos-bundle: macos-build
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@cp $(APP_BIN) $(APP_BUNDLE)/Contents/MacOS/AudioBunny
	@cp $(MACOS_DIR)/Info.plist $(APP_BUNDLE)/Contents/Info.plist

macos-run: macos-bundle
	open $(APP_BUNDLE)

# ── Web (Docker) ──────────────────────────────────────────────────────────────

web-up:
	@echo "▸ Starting web stack in Docker…"
	docker compose -f $(WEB_DIR)/docker-compose.yml up -d --build

web-down:
	docker compose -f $(WEB_DIR)/docker-compose.yml down

web-logs:
	docker compose -f $(WEB_DIR)/docker-compose.yml logs -f

# ── Help ──────────────────────────────────────────────────────────────────────

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  dev           Build macOS app, start web stack in Docker, launch app"
	@echo "  dev-down      Stop Docker web stack"
	@echo "  macos-build   Compile macOS app (swift build -c debug)"
	@echo "  macos-run     Build and launch macOS app"
	@echo "  web-up        Start web stack in Docker"
	@echo "  web-down      Stop Docker web stack"
	@echo "  web-logs      Tail Docker logs"

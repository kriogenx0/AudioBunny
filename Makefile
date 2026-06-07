MACOS_DIR := macos
WEB_DIR   := web
APP_BIN   := $(MACOS_DIR)/.build/debug/AudioBunny

.PHONY: dev dev-down macos-build macos-run web-up web-down help

# ── Dev: build macOS app + run web stack in Docker ───────────────────────────

dev: macos-build web-up
	@echo ""
	@echo "  macOS app → launching $(APP_BIN)"
	@echo "  Web app   → http://localhost:5173"
	@echo "  API       → http://localhost:3000"
	@echo ""
	@echo "  Ctrl-C or 'make dev-down' to stop Docker."
	@echo ""
	$(APP_BIN) &

dev-down: web-down

# ── macOS ─────────────────────────────────────────────────────────────────────

macos-build:
	@echo "▸ Building macOS app (debug)…"
	cd $(MACOS_DIR) && swift build -c debug

macos-run: macos-build
	$(APP_BIN)

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
	@echo "  dev           Build macOS app + start web stack in Docker"
	@echo "  dev-down      Stop Docker web stack"
	@echo "  macos-build   Build macOS app (swift build -c debug)"
	@echo "  macos-run     Build and launch macOS app"
	@echo "  web-up        Start web stack in Docker (build if needed)"
	@echo "  web-down      Stop Docker web stack"
	@echo "  web-logs      Tail Docker logs"

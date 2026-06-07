RAILS_DIR := rails
FE_DIR    := frontend

.PHONY: dev dev-down rails-setup rails-console rails-logs \
        docker-build docker-stop \
        cap-setup cap-deploy \
        clean help

# ── Dev: delegate to root Makefile ────────────────────────────────────────────
# Run 'make dev' from the project root instead.

dev:
	$(MAKE) -C .. dev

dev-down:
	docker compose down

# ── Rails setup (first-time local, outside Docker) ────────────────────────────

rails-setup:
	cd $(RAILS_DIR) && bundle install
	cd $(RAILS_DIR) && bundle exec rails db:create db:migrate db:seed

rails-console:
	cd $(RAILS_DIR) && bundle exec rails console

rails-logs:
	docker compose logs -f rails

# ── Docker ────────────────────────────────────────────────────────────────────

docker-build:
	docker compose build

docker-stop:
	docker compose down --remove-orphans

# ── Capistrano deployment ─────────────────────────────────────────────────────
# Usage: make cap-deploy HOST=deploy@yourserver.com
# Requires ssh access and rbenv + ruby installed on server

cap-setup:
	cd $(RAILS_DIR) && bundle exec cap production deploy:setup

cap-deploy:
	cd $(RAILS_DIR) && bundle exec cap production deploy

# ── Cleanup ───────────────────────────────────────────────────────────────────

clean:
	docker compose down --volumes --remove-orphans
	rm -f $(RAILS_DIR)/db/development.sqlite3 $(RAILS_DIR)/db/production.sqlite3

help:
	@echo "AudioBunny web targets:"
	@echo "  make dev          Build Docker images, start web stack, open macOS app in Xcode"
	@echo "  make dev-down     Stop Docker web stack"
	@echo "  make rails-setup  Install gems + seed DB (first-time local setup)"
	@echo "  make rails-logs   Tail Rails log from Docker"
	@echo "  make docker-build Rebuild Docker images"
	@echo "  make cap-deploy   Deploy to production via Capistrano"
	@echo "  make clean        Remove containers, volumes, and SQLite databases"

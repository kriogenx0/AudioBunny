PYTHON   := /opt/homebrew/bin/python3
API_DIR  := api
FE_DIR   := frontend
VENV     := $(API_DIR)/.venv
PIP      := $(VENV)/bin/pip
UVICORN  := $(VENV)/bin/uvicorn

IMAGE    := audiobunny
PORT     := 8000

.PHONY: dev install install-api install-fe api fe \
        docker-build docker-run docker-stop \
        deploy-setup deploy rollback \
        clean

dev: install
	@trap 'kill 0' SIGINT SIGTERM; \
	(cd $(API_DIR) && ../$(UVICORN) main:app --reload --port 8000) & \
	(cd $(FE_DIR) && npm run dev) & \
	wait

install: install-api install-fe

install-api: $(VENV)
	$(PIP) install -q fastapi "uvicorn[standard]" sqlmodel \
		"python-jose[cryptography]" "passlib[bcrypt]" python-multipart aiofiles

$(VENV):
	$(PYTHON) -m venv $(VENV)

install-fe: $(FE_DIR)/node_modules

$(FE_DIR)/node_modules: $(FE_DIR)/package.json
	cd $(FE_DIR) && npm install

api: install-api
	cd $(API_DIR) && ../$(UVICORN) main:app --reload --port 8000

fe: install-fe
	cd $(FE_DIR) && npm run dev

docker-build:
	docker build -t $(IMAGE) .

docker-run: docker-build
	docker run --rm -p $(PORT):8000 \
		-v "$$(pwd)/api/audiobunny.db:/app/audiobunny.db" \
		-v "$$(pwd)/api/thumbnails:/app/thumbnails" \
		-v "$$(pwd)/api/downloads:/app/downloads" \
		--name $(IMAGE) $(IMAGE)

docker-stop:
	docker stop $(IMAGE) 2>/dev/null || true

# ── Deployment (Fabric) ───────────────────────────────────────────────────────
# Usage: make deploy HOST=deploy@audiobunny.example.com
#        make rollback HOST=deploy@audiobunny.example.com

DEPLOY_VENV := deploy/.venv
HOST        ?= deploy@audiobunny.example.com

$(DEPLOY_VENV):
	python3 -m venv $(DEPLOY_VENV)
	$(DEPLOY_VENV)/bin/pip install -q -r deploy/requirements.txt

deploy-setup: $(DEPLOY_VENV)
	$(DEPLOY_VENV)/bin/fab -H $(HOST) setup

deploy: $(DEPLOY_VENV)
	$(DEPLOY_VENV)/bin/fab -H $(HOST) deploy

rollback: $(DEPLOY_VENV)
	$(DEPLOY_VENV)/bin/fab -H $(HOST) rollback

clean:
	rm -rf $(VENV) $(FE_DIR)/node_modules $(API_DIR)/audiobunny.db $(DEPLOY_VENV)

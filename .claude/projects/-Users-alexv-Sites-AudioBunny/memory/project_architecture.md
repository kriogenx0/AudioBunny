---
name: project-architecture
description: AudioBunny project structure, tech stack, and major features added in June 2026
metadata:
  type: project
---

AudioBunny is a cross-platform audio plugin manager with a macOS native app and a web application.

**Repository structure (as of June 2026):**
- `macos/` — Swift Package Manager macOS app (moved from root)
  - `macos/Sources/AudioBunny/` — all Swift source files
  - `macos/Package.swift` — SPM package manifest
  - `macos/AudioBunny/` — older Xcode project (kept for reference)
- `web/rails/` — Ruby on Rails 7.2 API-only backend (replaces Python FastAPI at `web/api/`)
- `web/frontend/` — React + TypeScript frontend (Vite, React Query)
- `web/docker-compose.yml` — Docker dev stack (Rails API + Vite frontend)
- `web/Dockerfile.rails` — Rails Docker image

**Why:** User requested robust preset system with user accounts, file uploads, and web→macOS install queue. Rails chosen over FastAPI for this scope.

**How to apply:** When making changes, be aware of dual codebase (Swift + Rails + React).

**Rails API base URL:** `/api/v1/` on port 3000
**Frontend proxy:** Vite proxies `/api` → `http://localhost:3000`
**`make dev` (from `web/`):** Builds Docker images, starts Rails API + Vite in Docker, opens macOS Package.swift in Xcode

**Key Rails models:** User, Plugin, Preset, Favorite, PresetFavorite, PresetInstall (status: queued/completed)
**Preset install queue:** Web app creates PresetInstall with status='queued'; macOS app polls GET /api/v1/installs/presets?status=queued every 30 seconds and downloads/installs, then calls PATCH to mark completed.

**Preset storage:** `web/rails/storage/presets/` (mounted as Docker volume)
**Preset install paths (macOS):** Serum → `~/Documents/Xfer/Serum Presets/Presets/AudioBunny/`, Guitar Rig 7 → `~/Documents/Native Instruments/Guitar Rig 7/Presets/AudioBunny/`

**Deployment:** Capistrano 3 via `make cap-deploy` (from `web/`), config at `web/rails/config/deploy.rb`

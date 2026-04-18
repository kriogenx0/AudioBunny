# ── Stage 1: build the React frontend ────────────────────────────────────────
FROM node:22-alpine AS frontend

WORKDIR /build
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

# ── Stage 2: API + serve built frontend ──────────────────────────────────────
FROM python:3.12-slim

WORKDIR /app

COPY api/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY api/ ./

# Copy the Vite build output into the location main.py looks for
COPY --from=frontend /build/dist ./frontend_dist

# Persistent data lives in a volume; pre-create the directories so the
# app can start without a mounted volume too.
RUN mkdir -p thumbnails downloads

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

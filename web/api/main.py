from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import os

from database import create_db_and_tables
from seed import seed
from routes_auth import router as auth_router
from routes_plugins import router as plugins_router
from routes_favorites import router as favorites_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    create_db_and_tables()
    seed()
    yield


app = FastAPI(title="AudioBunny API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:4173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(plugins_router)
app.include_router(favorites_router)

# Static asset directories (thumbnails / downloadable plugins)
_here = os.path.dirname(__file__)

thumbnails_dir = os.path.join(_here, "thumbnails")
os.makedirs(thumbnails_dir, exist_ok=True)
app.mount("/api/thumbnails", StaticFiles(directory=thumbnails_dir), name="thumbnails")

downloads_dir = os.path.join(_here, "downloads")
os.makedirs(downloads_dir, exist_ok=True)
app.mount("/api/downloads", StaticFiles(directory=downloads_dir), name="downloads")

# Serve the built React frontend when running inside Docker / production.
# In dev the Vite dev server handles the frontend directly.
frontend_dist = os.path.join(_here, "frontend_dist")
if os.path.isdir(frontend_dist):
    assets_dir = os.path.join(frontend_dist, "assets")
    if os.path.isdir(assets_dir):
        app.mount("/assets", StaticFiles(directory=assets_dir), name="assets")

    @app.get("/{full_path:path}", include_in_schema=False)
    async def serve_spa(_: str):
        return FileResponse(os.path.join(frontend_dist, "index.html"))

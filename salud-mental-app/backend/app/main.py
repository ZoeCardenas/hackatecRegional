# backend/app/main.py
"""
App FastAPI: CORS, lifespan (startup/shutdown), routers.
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .db.mongo import connect_to_mongo, disconnect_from_mongo, get_db
from .core.config import settings
from .routes import (
    auth, users, therapists, assessments, triage, sos,
    notifications, directory, content,
    ads,
    appointments
)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup (sin await porque connect_to_mongo es sync)
    connect_to_mongo()
    yield
    # Shutdown
    disconnect_from_mongo()

app = FastAPI(title="Salud Mental API", version="0.1.0", lifespan=lifespan)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=getattr(settings, "CORS_ORIGINS", ["*"]),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health", tags=["misc"])
async def health():
    return {"ok": True}

# Routers
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(users.router, prefix="/users", tags=["users"])
app.include_router(therapists.router, prefix="/therapists", tags=["therapists"])
app.include_router(assessments.router, prefix="/assessments", tags=["assessments"])
app.include_router(triage.router, prefix="/triage", tags=["triage"])
app.include_router(sos.router, prefix="/sos", tags=["sos"])
app.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
app.include_router(content.router, prefix="/content", tags=["content"])
app.include_router(directory.router, prefix="/directory", tags=["directory"])  # <- añadido para resolver 404
app.include_router(ads.router, prefix="/ads", tags=["ads"])
app.include_router(appointments.router, prefix="/appointments", tags=["appointments"])

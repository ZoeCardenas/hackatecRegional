# backend/app/main.py
"""
App FastAPI: CORS, lifespan (startup/shutdown), routers + middleware de trazas.
"""
import logging, time

# ⬇️ AÑADE ESTO MUY ARRIBA, ANTES DE IMPORTAR CUALQUIER ROUTER
from dotenv import load_dotenv, find_dotenv
load_dotenv(find_dotenv(), override=True)  # carga backend/.env

from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from .db.mongo import connect_to_mongo, disconnect_from_mongo
from .core.config import settings
from .routes import (
    auth, users, therapists, assessments, triage, sos,
    notifications, directory, content, ads, appointments,
    ai, flows
)

# -------- Logging raíz (útil en Windows/PowerShell) --------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s"
)
http_logger = logging.getLogger("app.http")

@asynccontextmanager
async def lifespan(app: FastAPI):
    connect_to_mongo()
    yield
    disconnect_from_mongo()

app = FastAPI(title="Salud Mental API", version="0.1.0", lifespan=lifespan)

# ---------------- CORS ----------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=getattr(settings, "CORS_ORIGINS", ["*"]),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------- Middleware de trazas ----------------
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    try:
        response = await call_next(request)
        dur = round(time.time() - start, 4)
        http_logger.info(f"{request.method} {request.url.path} -> {response.status_code} in {dur}s")
        return response
    except Exception as e:
        dur = round(time.time() - start, 4)
        http_logger.exception(f"{request.method} {request.url.path} EXC after {dur}s: {e}")
        raise

# ---------------- Healthcheck ----------------
@app.get("/health", tags=["misc"])
async def health():
    return {"ok": True}

# ---------------- Routers ----------------
app.include_router(auth.router,         prefix="/auth",         tags=["auth"])
app.include_router(users.router,        prefix="/users",        tags=["users"])
app.include_router(therapists.router,   prefix="/therapists",   tags=["therapists"])
app.include_router(assessments.router,  prefix="/assessments",  tags=["assessments"])
app.include_router(triage.router,       prefix="/triage",       tags=["triage"])
app.include_router(sos.router,          prefix="/sos",          tags=["sos"])
app.include_router(notifications.router,prefix="/notifications",tags=["notifications"])
app.include_router(content.router,      prefix="/content",      tags=["content"])
app.include_router(directory.router,    prefix="/directory",    tags=["directory"])
app.include_router(ads.router,          prefix="/ads",          tags=["ads"])
app.include_router(appointments.router, prefix="/appointments", tags=["appointments"])
app.include_router(ai.router,           prefix="/ai",           tags=["ai"])
app.include_router(flows.router,        prefix="/flows",        tags=["flows"])

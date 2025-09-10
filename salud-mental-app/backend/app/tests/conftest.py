# backend/app/tests/conftest.py
"""
Fixtures y helpers para pruebas end-to-end con FastAPI + pytest-asyncio.
Crea una DB única por corrida para evitar colisiones y levanta FastAPI con lifespan.
"""
import os
import sys
import uuid
from pathlib import Path

import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from asgi_lifespan import LifespanManager

# ---- DB de test única por corrida (debe setearse ANTES de importar app.main) ----
TEST_DB_NAME = f"salud_mental_test_{uuid.uuid4().hex[:8]}"
os.environ.setdefault("MONGO_DB", TEST_DB_NAME)

# ---- asegurar imports absolutos 'app.*' ----
ROOT_DIR = Path(__file__).resolve().parents[1]   # .../backend/app
sys.path.insert(0, str(ROOT_DIR.parent))         # .../backend

from app.main import app  # noqa

@pytest_asyncio.fixture
async def async_client():
    async with LifespanManager(app):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://testserver") as client:
            yield client

# -------- Helpers --------
async def _register(client: AsyncClient, *, role: str = "usuario"):
    email = f"test_{uuid.uuid4().hex[:8]}@example.com"
    payload = {"email": email, "password": "Secreta123", "name": "Zoe Test", "role": role}
    r = await client.post("/auth/register", json=payload)
    assert r.status_code in (200, 201), r.text
    return email

async def _login(client: AsyncClient, email: str):
    r = await client.post("/auth/login", json={"email": email, "password": "Secreta123"})
    assert r.status_code == 200, r.text
    token = r.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}

@pytest_asyncio.fixture
async def user_auth(async_client: AsyncClient):
    email = await _register(async_client, role="usuario")
    headers = await _login(async_client, email)
    return {"email": email, "headers": headers}

@pytest_asyncio.fixture
async def therapist_auth(async_client: AsyncClient):
    email = await _register(async_client, role="terapeuta")
    headers = await _login(async_client, email)
    return {"email": email, "headers": headers}

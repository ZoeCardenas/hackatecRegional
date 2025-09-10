# backend/app/tests/test_auth.py
import pytest

pytestmark = pytest.mark.asyncio

async def test_register_login_me(async_client):
    # Registro
    r1 = await async_client.post("/auth/register", json={
        "email": "auth_"+ "z@" + "mail.com",  # valor inútil, se sobreescribe abajo si repites
        "password": "Secreta123",
        "name": "Z",
        "role": "usuario"
    })
    assert r1.status_code in (200, 201)

    # Login
    email = r1.json()["email"]
    r2 = await async_client.post("/auth/login", json={"email": email, "password": "Secreta123"})
    assert r2.status_code == 200
    token = r2.json()["access_token"]

    # /me
    r3 = await async_client.get("/users/me", headers={"Authorization": f"Bearer {token}"})
    assert r3.status_code == 200
    me = r3.json()
    assert me["sub"] == email
    assert "role" in me

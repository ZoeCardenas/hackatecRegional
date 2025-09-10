# backend/app/tests/test_triage_ads.py
import pytest

pytestmark = pytest.mark.asyncio

async def test_triage_and_ads(user_auth, async_client):
    headers = user_auth["headers"]

    # Triage con texto de hopelessness eleva acciones
    r = await async_client.post("/triage/evaluate", headers=headers, json={
        "dass_level": 1,
        "text": "me siento sin esperanza"
    })
    assert r.status_code == 200
    out = r.json()
    assert out["risk_level"] >= 1
    assert "ocultar_ads" in out["actions"]

    # Ads desactivados en risk >= 1 o pantallas sensibles
    r2 = await async_client.get("/ads/slot?screen=home&risk_level=2")
    assert r2.status_code == 200
    assert r2.json()["show"] is False

    r3 = await async_client.get("/ads/slot?screen=chat&risk_level=0")
    assert r3.status_code == 200
    assert r3.json()["show"] is False

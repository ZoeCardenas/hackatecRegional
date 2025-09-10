# backend/app/tests/test_assessments.py
import pytest

pytestmark = pytest.mark.asyncio

async def test_dass21_flow(user_auth, async_client):
    headers = user_auth["headers"]
    # 21 respuestas en rango 0-3
    payload = {"answers": [0,1,2,1,0,1,2,1,0,1,2,1,0,1,2,1,0,1,2,1,0]}
    r = await async_client.post("/assessments/dass21", headers=headers, json=payload)
    assert r.status_code == 200
    data = r.json()
    assert "assessment_id" in data
    assert "score" in data
    assert set(data["score"].keys()) == {"D","A","S","total","risk_level"}

    # Historial
    r2 = await async_client.get("/assessments/history?limit=3", headers=headers)
    assert r2.status_code == 200
    assert isinstance(r2.json(), list)

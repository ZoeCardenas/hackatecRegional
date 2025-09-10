# backend/app/tests/test_therapists_directory.py
import pytest

pytestmark = pytest.mark.asyncio

async def test_create_and_search_therapist(therapist_auth, async_client):
    headers = therapist_auth["headers"]

    # Alta de terapeuta (requiere role 'terapeuta' o 'admin')
    payload = {
        "name": "Dra. Ana",
        "license": "CED-12345",
        "specialties": ["ansiedad","depresion"],
        "regions": ["CDMX"],
        "convenio": True,
        "contact_email": "ana@example.com"
    }
    r = await async_client.post("/therapists", headers=headers, json=payload)
    assert r.status_code == 200
    ther = r.json()
    assert ther["name"] == "Dra. Ana"

    # Directorio
    r2 = await async_client.get("/directory/search?q=ansiedad")
    assert r2.status_code == 200
    arr = r2.json()
    assert any(t["name"] == "Dra. Ana" for t in arr)

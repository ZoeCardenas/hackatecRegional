# backend/app/tests/test_appointments.py
import pytest
from datetime import datetime, timedelta, timezone

pytestmark = pytest.mark.asyncio

async def test_appointment_crud(user_auth, async_client):
    headers = user_auth["headers"]

    # Crear cita (futuro)
    when = (datetime.now(tz=timezone.utc) + timedelta(days=3)).isoformat()
    payload = {"therapist_id": "abc123", "when": when, "note": "Primera sesión"}
    r = await async_client.post("/appointments", headers=headers, json=payload)
    assert r.status_code == 200
    appt = r.json()
    assert appt["status"] == "pending"

    # Mis citas
    r2 = await async_client.get("/appointments/mine", headers=headers)
    assert r2.status_code == 200
    arr = r2.json()
    assert any(a["id"] == appt["id"] for a in arr)

    # Actualizar estado
    r3 = await async_client.patch(f"/appointments/{appt['id']}", headers=headers, json={"status":"confirmed"})
    assert r3.status_code == 200
    assert r3.json()["status"] == "confirmed"

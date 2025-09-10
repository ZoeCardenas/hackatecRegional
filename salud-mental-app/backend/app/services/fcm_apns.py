"""
FCM/APNs stub:
- En producción: usar credenciales de FCM y/o certificados APNs.
- Aquí solo simula programación/envío para pruebas de integración.
"""
from pydantic import BaseModel

class PushPayload(BaseModel):
    token: str | None = None
    title: str
    body: str
    data: dict | None = None

async def send_push(payload: PushPayload) -> dict:
    # TODO: integrar fcm-django o pyfcm, etc.
    return {"ok": True, "preview": payload.model_dump()}

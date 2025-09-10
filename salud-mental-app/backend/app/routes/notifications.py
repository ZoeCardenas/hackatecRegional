"""
Stub de notificaciones push. En producción: integra FCM/APNs en services/fcm_apns.py
"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from ..core.deps import current_user

router = APIRouter()

class NotifyIn(BaseModel):
    title: str
    body: str
    token: str | None = None   # token de push del dispositivo (si lo tienes)

@router.post("/test", summary="Probar envío de notificación (stub)")
async def test_notify(payload: NotifyIn, user=Depends(current_user)):
    # Aquí llamarías a services/fcm_apns.send(...)
    return {"status": "scheduled", "preview": payload.model_dump()}

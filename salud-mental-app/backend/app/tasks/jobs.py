"""
Jobs recurrentes/one-shot.
Este módulo define funciones idempotentes que pueden ser programadas por el scheduler
local (stub) o por un worker real (Celery/RQ) más adelante.
"""
from datetime import datetime
from typing import Optional
import asyncio

# En producción, importarías send_push y repos para leer DB.
from ..services.fcm_apns import send_push, PushPayload

async def job_daily_message(user_id: str, message: str) -> dict:
    """
    Envía un mensaje diario motivacional al usuario (push).
    Debe ser idempotente y rápido; si requiere datos, traerlos aquí.
    """
    payload = PushPayload(token=None, title="Mensaje diario", body=message, data={"user_id": user_id})
    return await send_push(payload)

async def job_appointment_reminder(user_id: str, appointment_id: str, hours_before: int) -> dict:
    """
    Recordatorio de cita.
    """
    body = f"Tienes una cita en {hours_before}h. ¿Deseas confirmar o reprogramar?"
    payload = PushPayload(token=None, title="Recordatorio de cita", body=body, data={"appointment_id": appointment_id})
    return await send_push(payload)

async def job_post_sos_checkin(user_id: str, after_hours: int) -> dict:
    """
    Check-in tras evento SOS (p. ej., a las 2h y 24h).
    """
    body = "¿Cómo te sientes ahora? Estoy aquí si necesitas apoyo. Puedo contactar ayuda."
    payload = PushPayload(token=None, title="Estoy aquí contigo", body=body, data={"after_hours": after_hours})
    return await send_push(payload)

def fire_and_forget(coro):
    """
    Ejecuta una corrutina sin bloquear (para uso dentro de endpoints).
    """
    asyncio.create_task(coro)

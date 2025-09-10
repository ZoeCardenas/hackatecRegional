"""
Worker/scheduler sencillo con APScheduler opcional o modo asyncio puro.
- Por simplicidad, exponemos funciones para programar en caliente desde la API.
- En producción, reemplazar por Celery/RQ + Redis para persistencia y reintentos.
"""
from datetime import datetime, timedelta
import asyncio

from .jobs import job_daily_message, job_appointment_reminder, job_post_sos_checkin

# ===== Modo asyncio puro (no persistente) =====

def schedule_daily_message_at(user_id: str, first_run: datetime, message: str) -> None:
    """
    Programa un envío único (ejemplo), que podría reprogramarse al completarse.
    """
    delay = max(0, (first_run - datetime.utcnow()).total_seconds())
    asyncio.create_task(_run_once(delay, job_daily_message(user_id, message)))

def schedule_appointment_reminders(appointment_id: str, user_id: str, when: datetime) -> None:
    """
    Programa recordatorios t-24h y t-2h relativos a 'when'.
    """
    now = datetime.utcnow()
    for hours in (24, 2):
        at = when - timedelta(hours=hours)
        delay = max(0, (at - now).total_seconds())
        asyncio.create_task(_run_once(delay, job_appointment_reminder(user_id, appointment_id, hours)))

def schedule_post_sos_checkins(user_id: str) -> None:
    """
    Programa check-ins a +2h y +24h después de un SOS.
    """
    now = datetime.utcnow()
    for h in (2, 24):
        at = now + timedelta(hours=h)
        delay = (at - now).total_seconds()
        asyncio.create_task(_run_once(delay, job_post_sos_checkin(user_id, h)))

async def _run_once(delay: float, coro):
    """
    Espera 'delay' segundos y luego ejecuta la corrutina dada.
    """
    await asyncio.sleep(delay)
    await coro

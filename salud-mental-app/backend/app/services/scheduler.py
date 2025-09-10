# app/services/scheduler.py
"""
Scheduler ligero basado en asyncio (MVP).
En producción: Celery/RQ + Redis, con reintentos y persistencia.
"""
import asyncio
from datetime import datetime, timedelta, timezone
from typing import Any, Mapping, Optional
from ..models.appointment import AppointmentPublic
from .fcm_apns import send_push, PushPayload


def _get(appt: Any, key: str) -> Any:
    """Obtiene un campo ya sea por atributo (modelo) o dict."""
    if isinstance(appt, Mapping):
        return appt.get(key)
    return getattr(appt, key, None)


def _coerce_when(value: Any) -> Optional[datetime]:
    """Convierte str ISO8601 o datetime a datetime con tz UTC."""
    if value is None:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
    return None


def schedule_appointment_reminders(appt: AppointmentPublic | Mapping[str, Any]) -> None:
    """
    Programa recordatorios a t-24h y t-2h.
    Tolera que 'appt' sea un dict (como en los tests) o un modelo Pydantic.
    """
    when_dt = _coerce_when(_get(appt, "when"))
    if not when_dt:
        return

    now = datetime.now(timezone.utc)
    for hours in (24, 2):
        fire_at = when_dt - timedelta(hours=hours)
        delay = max(0.0, (fire_at - now).total_seconds())
        asyncio.create_task(_reminder_task(appt, delay, hours))


async def _reminder_task(appt: Any, delay: float, hours: int) -> None:
    await asyncio.sleep(delay)
    appt_id = _get(appt, "id") or _get(appt, "_id")
    await send_push(
        PushPayload(
            token=None,  # Token real en producción
            title="Recordatorio de cita",
            body=f"Tienes una cita en {hours}h con tu terapeuta.",
            data={"appointment_id": str(appt_id) if appt_id else None},
        )
    )

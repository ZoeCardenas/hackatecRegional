# app/routes/appointments.py

from fastapi import APIRouter, Depends, HTTPException, status
from anyio import to_thread
from datetime import datetime, timezone
from typing import Dict, Any, List
from bson import ObjectId

from ..core.deps import current_db, current_user
from ..models.appointment import (
    AppointmentCreate,
    AppointmentUpdate,
    AppointmentPublic,
)
from ..services.scheduler import schedule_appointment_reminders

router = APIRouter()


def _to_public(doc: Dict[str, Any]) -> Dict[str, Any]:
    """Convierte un doc de Mongo en dict serializable por AppointmentPublic (id como alias)."""
    out = dict(doc)
    if "_id" in out and not isinstance(out["_id"], str):
        out["_id"] = str(out["_id"])
    return out


@router.post(
    "",
    response_model=AppointmentPublic,
    response_model_by_alias=False,   # fuerza "id" (no "_id")
    summary="Crear cita",
)
async def create_appointment(
    payload: AppointmentCreate,
    db=Depends(current_db),
    user=Depends(current_user),
):
    col = db["appointments"]

    # Normaliza 'when' a UTC naive si viene con tz (test usa tz_aware=False)
    when_dt = payload.when
    if isinstance(when_dt, datetime) and when_dt.tzinfo is not None:
        when_dt = when_dt.astimezone(timezone.utc).replace(tzinfo=None)

    created_at = datetime.now(timezone.utc).replace(tzinfo=None)

    doc: Dict[str, Any] = {
        "user_id": user["sub"],
        "therapist_id": payload.therapist_id,
        "when": when_dt,
        "note": payload.note,
        "status": "pending",
        "created_at": created_at,
    }

    def _insert_one():
        res = col.insert_one(doc)  # PyMongo muta doc["_id"] con ObjectId
        return res.inserted_id

    inserted_id = await to_thread.run_sync(_insert_one)

    # Construye salida desde doc y fuerza "_id" al final como string
    appt_out: Dict[str, Any] = {**doc}
    appt_out["_id"] = str(appt_out.get("_id", inserted_id))

    # El scheduler no debe romper la respuesta
    try:
        schedule_appointment_reminders(appt_out)  # acepta dict o modelo
    except Exception:
        pass

    return appt_out


@router.get(
    "",
    response_model=list[AppointmentPublic],
    response_model_by_alias=False,   # lista con "id"
    summary="Listar mis citas",
)
async def list_root(db=Depends(current_db), user=Depends(current_user)):
    col = db["appointments"]

    def _fetch():
        cur = col.find({"user_id": user["sub"]}).sort("when", 1)
        return [_to_public(d) for d in cur]

    rows = await to_thread.run_sync(_fetch)
    return rows


@router.get(
    "/mine",
    response_model=list[AppointmentPublic],
    response_model_by_alias=False,   # alias desactivado
    summary="Listar mis citas (alias)",
)
async def list_mine(db=Depends(current_db), user=Depends(current_user)):
    col = db["appointments"]

    def _fetch():
        cur = col.find({"user_id": user["sub"]}).sort("when", 1)
        return [_to_public(d) for d in cur]

    rows = await to_thread.run_sync(_fetch)
    return rows


@router.patch(
    "/{appointment_id}",
    response_model=AppointmentPublic,
    response_model_by_alias=False,   # devuelve "id"
    summary="Actualizar estado de una cita",
)
async def update_appointment(
    appointment_id: str,
    payload: AppointmentUpdate,
    db=Depends(current_db),
    user=Depends(current_user),
):
    col = db["appointments"]

    def _update():
        try:
            oid = ObjectId(appointment_id)
        except Exception:
            return None
        doc = col.find_one_and_update(
            {"_id": oid},
            {"$set": {"status": payload.status}},
            return_document=True,  # ReturnDocument.AFTER equivalente
        )
        return doc

    updated = await to_thread.run_sync(_update)
    if not updated:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="appointment_not_found")

    appt = _to_public(updated)

    # Autorización: dueño o admin/terapeuta
    if appt.get("user_id") != user["sub"] and user.get("role") not in ("admin", "terapeuta"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No autorizado")

    return appt

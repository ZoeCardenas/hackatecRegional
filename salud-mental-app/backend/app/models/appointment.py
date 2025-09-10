# app/models/appointment.py
from __future__ import annotations
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Literal

from anyio import to_thread
from pydantic import BaseModel, Field
from pymongo import ReturnDocument
from bson import ObjectId


class AppointmentCreate(BaseModel):
    therapist_id: str
    when: datetime
    note: Optional[str] = None


class AppointmentUpdate(BaseModel):
    # 🔑 Agregamos "confirmed" porque el test hace PATCH con ese estado
    status: Literal["pending", "scheduled", "confirmed", "cancelled", "completed"]


class AppointmentPublic(BaseModel):
    id: str = Field(..., alias="_id")
    user_id: str
    therapist_id: str
    when: datetime
    note: Optional[str] = None
    # 🔑 Aquí también incluimos "confirmed"
    status: Literal["pending", "scheduled", "confirmed", "cancelled", "completed"]
    created_at: datetime

    class Config:
        populate_by_name = True
        allow_population_by_field_name = True
        json_encoders = {datetime: lambda v: v.isoformat()}


class AppointmentRepo:
    def __init__(self, db):
        self.col = db["appointments"]

    async def create(self, *, user_id: str, payload: AppointmentCreate) -> Dict[str, Any]:
        doc: Dict[str, Any] = {
            "user_id": user_id,
            "therapist_id": payload.therapist_id,
            "when": payload.when,
            "note": payload.note,
            "status": "pending",  # estado inicial
            "created_at": datetime.now(timezone.utc),
        }

        def _insert():
            res = self.col.insert_one(doc)
            return str(res.inserted_id)

        inserted_id = await to_thread.run_sync(_insert)
        doc["_id"] = inserted_id
        # devolvemos dict con

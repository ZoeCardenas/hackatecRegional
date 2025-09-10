# app/models/therapist.py
from __future__ import annotations
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from anyio import to_thread
from pydantic import BaseModel, Field, EmailStr
import re


# ---------- Pydantic ----------
class TherapistCreate(BaseModel):
    name: str
    license: str
    specialties: List[str] = []
    regions: List[str] = []
    convenio: bool = False
    contact_email: Optional[EmailStr] = None


class TherapistPublic(BaseModel):
    id: str = Field(..., alias="_id")
    name: str
    license: str
    specialties: List[str] = []
    regions: List[str] = []
    convenio: bool = False
    contact_email: Optional[EmailStr] = None

    class Config:
        populate_by_name = True
        allow_population_by_field_name = True


# ---------- Repository ----------
class TherapistRepo:
    def __init__(self, db):
        self.col = db["therapists"]

    async def create(self, data: TherapistCreate) -> Dict[str, Any]:
        doc: Dict[str, Any] = {
            "name": data.name,
            "license": data.license,
            "specialties": list(data.specialties or []),
            "regions": list(data.regions or []),
            "convenio": bool(data.convenio),
            "contact_email": data.contact_email,
            "created_at": datetime.now(timezone.utc),
        }
        if data.contact_email:
            doc["email"] = str(data.contact_email)

        def _insert():
            res = self.col.insert_one(doc)
            return str(res.inserted_id)

        inserted_id = await to_thread.run_sync(_insert)
        doc["_id"] = inserted_id
        return TherapistPublic.model_validate(doc).model_dump(by_alias=True)

    async def search(
        self,
        specialty: Optional[str] = None,
        region: Optional[str] = None,
        convenio: Optional[bool] = None,
        limit: int = 20,
    ) -> List[Dict[str, Any]]:
        """
        Búsqueda flexible:
        - Si specialty y region vienen del mismo 'q', hace OR sobre specialties/regions/name (regex, case-insensitive).
        - Si se especifican por separado, combina con AND.
        """
        # Construcción de cláusulas
        clauses: List[Dict[str, Any]] = []
        q_or = False

        # Detecta si ambos vienen iguales (típico de /directory?q=...):
        if specialty and region and specialty == region:
            # OR en specialties, regions y name
            pat = re.escape(specialty)
            ci = {"$regex": pat, "$options": "i"}
            clauses = [
                {"specialties": ci},
                {"regions": ci},
                {"name": ci},
            ]
            q_or = True
        else:
            if specialty:
                clauses.append({"specialties": {"$regex": re.escape(specialty), "$options": "i"}})
            if region:
                clauses.append({"regions": {"$regex": re.escape(region), "$options": "i"}})

        query: Dict[str, Any] = {}
        if clauses:
            query = {"$or": clauses} if q_or else (clauses[0] if len(clauses) == 1 else {"$and": clauses})

        if convenio is not None:
            # agrega condición de convenio manteniendo la estructura
            if not query:
                query = {"convenio": convenio}
            elif "$or" in query:
                query = {"$and": [query, {"convenio": convenio}]}
            else:
                query["convenio"] = convenio

        def _fetch():
            cur = self.col.find(query).limit(limit)
            out: List[Dict[str, Any]] = []
            for d in cur:
                d["_id"] = str(d["_id"])
                out.append(d)
            return out

        docs = await to_thread.run_sync(_fetch)
        return [TherapistPublic.model_validate(d).model_dump(by_alias=True) for d in docs]

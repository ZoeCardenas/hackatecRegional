# app/models/user.py
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, Optional

from anyio import to_thread
from pydantic import BaseModel, EmailStr, Field
from passlib.hash import bcrypt


# ---------- Pydantic ----------
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    name: str
    role: str = "usuario"  # "usuario" | "terapeuta" | "admin"


class UserPublic(BaseModel):
    id: str = Field(..., alias="_id")
    email: EmailStr
    name: str
    role: str

    class Config:
        populate_by_name = True


# ---------- helpers de contraseña ----------
def hash_password(password: str) -> str:
    return bcrypt.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return bcrypt.verify(password, password_hash)


# ---------- Repo ----------
class UserRepo:
    def __init__(self, db):
        self.col = db["users"]

    async def create(self, data: UserCreate) -> UserPublic:
        doc: Dict[str, Any] = {
            "email": str(data.email),
            "name": data.name,
            "role": data.role,
            "password_hash": hash_password(data.password),
            "created_at": datetime.now(timezone.utc),
        }

        def _insert() -> str:
            res = self.col.insert_one(doc)
            return str(res.inserted_id)

        inserted_id = await to_thread.run_sync(_insert)
        doc["_id"] = inserted_id

        public = {
            "_id": doc["_id"],
            "email": doc["email"],
            "name": doc["name"],
            "role": doc["role"],
        }
        return UserPublic.model_validate(public)

    async def get_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        """
        Retorna el documento completo (incluye password_hash).
        Ideal para login.
        """
        def _find() -> Optional[Dict[str, Any]]:
            d = self.col.find_one({"email": email})
            if not d:
                return None
            d["_id"] = str(d["_id"])
            return d

        return await to_thread.run_sync(_find)

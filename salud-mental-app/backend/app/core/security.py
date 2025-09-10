"""
Utilidades de seguridad: hash de contraseñas y JWT.
- Usa bcrypt para hashear.
- Usa JWT con expiración corta y refresh por separado (futuro).
"""
from datetime import datetime, timedelta, timezone
from typing import Any, Optional
from jose import jwt
from passlib.context import CryptContext
from ..core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
ALGO = "HS256"

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(password: str, password_hash: str) -> bool:
    return pwd_context.verify(password, password_hash)

def create_jwt(subject: dict[str, Any], expires_minutes: int | None = None) -> str:
    exp_min = expires_minutes if expires_minutes is not None else settings.JWT_EXPIRES_MIN
    to_encode = {
        "sub": subject.get("sub"),
        "role": subject.get("role"),
        "exp": datetime.now(tz=timezone.utc) + timedelta(minutes=exp_min),
        "iat": datetime.now(tz=timezone.utc),
    }
    return jwt.encode(to_encode, settings.JWT_SECRET, algorithm=ALGO)

def decode_jwt(token: str) -> dict[str, Any]:
    return jwt.decode(token, settings.JWT_SECRET, algorithms=[ALGO])

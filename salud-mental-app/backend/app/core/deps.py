"""
Dependencias comunes para FastAPI:
- current_db
- current_user (via Authorization: Bearer <token>)
"""
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from motor.motor_asyncio import AsyncIOMotorDatabase
from ..db.mongo import get_db
from ..core.security import decode_jwt

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

def current_db() -> AsyncIOMotorDatabase:
    return get_db()

async def current_user(token: str = Depends(oauth2_scheme)) -> dict:
    try:
        payload = decode_jwt(token)
        return {"sub": payload["sub"], "role": payload.get("role")}
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido")

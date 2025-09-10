# app/services/auth_service.py
"""
Servicio de autenticación: validar usuario/contraseña y emitir JWT.
"""
from fastapi import HTTPException, status
from ..models.user import UserRepo, verify_password
from ..core.security import create_jwt


class AuthService:
    def __init__(self, user_repo: UserRepo) -> None:
        self.user_repo = user_repo

    async def authenticate(self, email: str, password: str) -> str:
        user = await self.user_repo.get_by_email(email)
        if not user or not verify_password(password, user["password_hash"]):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales inválidas"
            )

        # 🔑 usamos el email como `sub` para que el test pase
        token = create_jwt({"sub": user["email"], "role": user["role"]})
        return token

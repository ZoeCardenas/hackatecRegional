# app/routes/auth.py
from fastapi import APIRouter, Depends
from pydantic import BaseModel, EmailStr
from ..core.deps import current_db
from ..models.user import UserCreate, UserRepo, UserPublic
from ..services.auth_service import AuthService

router = APIRouter()


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


@router.post("/register", response_model=UserPublic, summary="Registrar usuario")
async def register(payload: UserCreate, db=Depends(current_db)):
    """
    Crea un usuario con rol por defecto 'usuario'.
    """
    repo = UserRepo(db)
    u = await repo.create(payload)  # ya devuelve UserPublic
    return u


@router.post("/login", response_model=TokenOut, summary="Login y obtención de JWT")
async def login(payload: LoginIn, db=Depends(current_db)):
    repo = UserRepo(db)
    svc = AuthService(repo)
    token = await svc.authenticate(payload.email, payload.password)
    return TokenOut(access_token=token)

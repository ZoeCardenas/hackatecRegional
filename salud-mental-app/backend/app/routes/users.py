from fastapi import APIRouter, Depends
from ..core.deps import current_user

router = APIRouter()

@router.get("/me", summary="Datos del usuario autenticado")
async def me(user=Depends(current_user)):
    """
    Retorna el sujeto del token (email) y su rol.
    """
    return user

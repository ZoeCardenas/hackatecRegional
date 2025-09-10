"""
Entrega JSON versionado desde el filesystem (content/...). Simplifica el modo offline/online.
"""
from fastapi import APIRouter, Query
from fastapi.responses import FileResponse
from pathlib import Path
from ..core.config import settings

router = APIRouter()

@router.get("/daily", summary="Mensajes diarios por locale y versión")
async def daily(locale: str = Query(default="es-MX"), version: str = Query(default="2025-09-01")):
    path = Path(settings.CONTENT_DIR) / locale / f"daily_messages.v{version}.json"
    if not path.exists():
        from fastapi import HTTPException, status
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Contenido no encontrado")
    return FileResponse(path)

@router.get("/exercises", summary="Ejercicios por locale y versión")
async def exercises(locale: str = "es-MX", version: str = "2025-09-01"):
    path = Path(settings.CONTENT_DIR) / locale / f"exercises.v{version}.json"
    if not path.exists():
        from fastapi import HTTPException, status
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Contenido no encontrado")
    return FileResponse(path)

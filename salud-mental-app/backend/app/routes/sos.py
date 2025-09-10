from fastapi import APIRouter, Depends
from ..core.deps import current_user
from ..services.emergency_line import get_mx_emergency

router = APIRouter()

@router.post("/trigger", summary="Activar protocolo SOS (MX)")
async def sos_trigger(user=Depends(current_user)):
    """
    Devuelve números de emergencia y pasos inmediatos de estabilización.
    El frontend debe deshabilitar anuncios y priorizar salida de crisis.
    """
    resp = get_mx_emergency()
    return resp.model_dump()

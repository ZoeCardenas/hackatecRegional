from fastapi import APIRouter, Depends
from pydantic import BaseModel
from ..core.deps import current_user
from ..services.risk_engine import combine_risk
from ..services.chatbot_service import text_to_flags
from ..services.typing import RiskLevel

router = APIRouter()

class TriageIn(BaseModel):
    dass_level: RiskLevel
    text: str | None = None

@router.post("/evaluate", summary="Combinar riesgo DASS + texto")
async def evaluate(payload: TriageIn, user=Depends(current_user)):
    flags = text_to_flags(payload.text or "")
    final_level = combine_risk(payload.dass_level, flags)
    actions = []
    if final_level >= 1:
        actions.append("ocultar_ads")
    if final_level >= 2:
        actions += ["mostrar_sos", "notificar_terapeuta_si_consentido"]
    if final_level >= 3:
        actions += ["forzar_pantalla_crisis", "ofrecer_llamada_911_linea_vida"]
    return {"risk_level": final_level, "flags": flags, "actions": actions}

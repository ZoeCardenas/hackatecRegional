from fastapi import APIRouter, Query
from pydantic import BaseModel
from ..services.ads_decider import should_show_ads

router = APIRouter()

class AdsOut(BaseModel):
    show: bool

@router.get("/slot", response_model=AdsOut, summary="Decidir si mostrar banner")
async def slot(screen: str = Query(default="home"), risk_level: int = 0):
    return AdsOut(show=should_show_ads(screen=screen, risk_level=risk_level))

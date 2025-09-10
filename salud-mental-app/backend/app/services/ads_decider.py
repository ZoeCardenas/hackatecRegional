"""
Decisor de anuncios: aplica política ética.
- No mostrar si risk >= 1 (medio, alto, crítico).
- Solo en pantallas permitidas.
"""
from typing import Literal

Screen = Literal["home","directory","chat","sos","assessments","appointments"]

def should_show_ads(screen: Screen, risk_level: int) -> bool:
    if screen in ("chat","sos","assessments"):
        return False
    if risk_level >= 1:
        return False
    return screen in ("home","directory")

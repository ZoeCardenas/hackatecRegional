"""
Motor de riesgo: combina DASS-21 y heurísticas simples de texto (placeholder).
En producción: añade NLU/regex y señales adicionales (latencia, etc.).
"""
from .typing import RiskLevel

def combine_risk(dass_level: RiskLevel, text_flags: list[str] | None = None) -> RiskLevel:
    """
    - Si hay bandera de ideación explícita → crítico (3)
    - Si hay banderas de desesperanza → eleva un nivel
    - En otro caso: usa DASS
    """
    text_flags = text_flags or []
    if "explicit_ideation" in text_flags:
        return 3
    if "hopelessness" in text_flags and dass_level < 3:
        return min(3, dass_level + 1)
    return dass_level

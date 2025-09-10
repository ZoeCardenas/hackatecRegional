"""
Heurística simple de detección de banderas por texto (placeholder).
En producción: usar NLU y listas curadas, con guardrails.
"""
def text_to_flags(text: str) -> list[str]:
    t = (text or "").lower()
    flags = []
    if any(p in t for p in ["quiero morir", "quitarme la vida", "suicid", "me mato"]):
        flags.append("explicit_ideation")
    if any(p in t for p in ["sin esperanza", "no vale la pena", "no puedo más"]):
        flags.append("hopelessness")
    return flags

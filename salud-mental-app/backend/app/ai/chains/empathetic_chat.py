"""
Cadena de chat empático (MVP seguro).
- Carga prompt de sistema y lista de guardrails desde /ai/prompts.
- (Opcional) Usa Ollama vía LangChain si hay servidor; si no, responde fallback
  con guías empáticas y SIN contenido peligroso.
- Detecta banderas de crisis y deriva al flujo de crisis.
"""
from pathlib import Path
from typing import Optional, Dict

try:
    # Opcional: si tienes langchain y ollama corriendo
    from langchain.llms import Ollama  # type: ignore
    _LC_AVAILABLE = True
except Exception:
    _LC_AVAILABLE = False

from ..settings import OLLAMA_MODEL
from ...services.chatbot_service import text_to_flags
from .crisis_flow import crisis_response

PROMPTS_DIR = Path(__file__).resolve().parents[1] / "prompts"

def _load(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""

SYSTEM = _load(PROMPTS_DIR / "system_sano.txt")
BLOCKLIST = [l.strip() for l in _load(PROMPTS_DIR / "guardrails_bloqueo.txt").splitlines() if l.strip()]
ESCALATION = _load(PROMPTS_DIR / "escalation_templates.txt")

# Personas disponibles para el avatar (niño, niña, tortuga)
PERSONAS: Dict[str, str] = {
    "nino": "Tono tierno y directo, frases cortas, metáforas sencillas.",
    "nina": "Tono cálido y curioso, valida la emoción y propone pasos cortos.",
    "tortuga": "Tono pausado, invita a ir lento y respirar, usa visualizaciones de seguridad."
}

def _blocked(text: str) -> bool:
    t = text.lower()
    return any(p in t for p in BLOCKLIST)

def generate_response(user_text: str, persona: str = "tortuga") -> str:
    """
    Genera respuesta empática segura.
    - Si hay ideación explícita → usa crisis_flow (deriva).
    - Si aparecen frases bloqueadas → corta y deriva a ayuda.
    - Si no hay LLM, usa respuesta heurística empática.
    """
    persona_desc = PERSONAS.get(persona, PERSONAS["tortuga"])
    flags = text_to_flags(user_text)

    if "explicit_ideation" in flags or _blocked(user_text):
        return crisis_response(user_text)

    # Si hay LangChain + Ollama disponible, intentamos usarlo con prompt seguro
    if _LC_AVAILABLE:
        try:
            sys_prompt = (
                f"{SYSTEM}\n\n"
                f"--- CONTEXTO PERSONA ---\n{persona_desc}\n"
                f"--- REGLAS ---\nNo entregues métodos de autolesión ni contenido detallado de daño. "
                f"Si detectas riesgo, limita respuesta y deriva a ayuda profesional.\n"
            )
            llm = Ollama(model=OLLAMA_MODEL, system=sys_prompt, temperature=0.4)
            out = llm(user_text).strip()
            # Guardrail post: si LLM se va de tema, devolvemos fallback empático.
            if _blocked(out):
                return crisis_response(user_text)
            return out[:900]  # límite de seguridad
        except Exception:
            pass

    # Fallback sin LLM: respuesta empática breve y segura
    return (
        "Gracias por confiarme esto. Estoy aquí contigo. "
        "¿Te parece si hacemos una respiración 4-4-6 (inhala 4, sostén 4, exhala 6) "
        "y luego me cuentas qué parte se siente más pesada ahora mismo?\n"
        "Si en algún momento te sientes en riesgo, puedo mostrarte el botón SOS "
        "o ayudarte a contactar a la Línea de la Vida (800 911 2000) o 911."
    )

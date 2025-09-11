# app/routes/flows.py
from fastapi import APIRouter, Body, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
from bson import ObjectId  # <- usar ObjectId real
from ..db.mongo import get_db

router = APIRouter()

# ------------------------- MODELOS -------------------------
class StartSessionIn(BaseModel):
    user_id: Optional[str] = None
    channel: str = "web"

class DassAnswerIn(BaseModel):
    session_id: str
    index: int = Field(ge=0, le=20)     # 0..20
    value: int = Field(ge=0, le=3)      # 0..3

class NegotiationIn(BaseModel):
    session_id: str
    user_message: str

class EeaStepIn(BaseModel):
    session_id: str
    step_key: str   # "eleccion_del_evento", "escritura_libre", etc.
    user_text: str

# ------------------------- HELPERS -------------------------
def _oid(s: str) -> ObjectId:
    try:
        return ObjectId(s)
    except Exception:
        raise HTTPException(400, "session_id inválido")

# ------------------------- DASS-21 -------------------------
# 0..20 (21 ítems). Respuestas 0..3. Multiplicar subescalas * 2
DASS21_QUESTIONS = [
    "Encontré difícil relajarme.",
    "Me di cuenta que tenía la boca seca.",
    "No parecía sentir ningún sentimiento positivo.",
    "Tuve dificultad para respirar (p. ej. respiración acelerada).",
    "Me costó iniciativa para hacer las cosas.",
    "Reaccioné de forma exagerada a situaciones.",
    "Sentí temblores (p. ej. en las manos).",
    "Sentí que estaba usando mucha energía nerviosa.",
    "Me preocupaba que situaciones me hicieran entrar en pánico y hacer el ridículo.",
    "No tuve nada que esperar con ilusión.",
    "Me sentí agitado/a.",
    "Me costó relajarme.",
    "Me sentí triste y deprimido/a.",
    "No toleré nada que impidiera que continúe con lo que estaba haciendo.",
    "Sentí que estaba cerca de entrar en pánico.",
    "No sentí entusiasmo por nada.",
    "Me sentí intolerante con cosas que generalmente tolero.",
    "Sentí que no valía mucho como persona.",
    "Me sentí bastante irritable.",
    "Noté cambios en mi ritmo cardiaco (p. ej. latidos acelerados).",
    "Sentí miedo sin una buena razón."
]

# índices por subescala (oficial DASS-21)
DEP_IDX  = [2, 4, 9, 12, 15, 16, 20]     # +1 en humano; aquí 0-based
ANX_IDX  = [1, 3, 6, 8, 14, 18, 19]
STR_IDX  = [0, 5, 7, 10, 11, 13, 17]

def _sum_items(vals: List[int], idx: List[int]) -> int:
    return sum(vals[i] for i in idx)

def _severity(score: int, kind: str) -> str:
    # rangos sugeridos (DASS21*2 -> 0..42 por subescala)
    if kind == "DEP":
        s = score
        if s <= 9:  return "normal"
        if s <= 13: return "leve"
        if s <= 20: return "moderado"
        if s <= 27: return "severo"
        return "extremo"
    if kind == "ANX":
        s = score
        if s <= 7:  return "normal"
        if s <= 9:  return "leve"
        if s <= 14: return "moderado"
        if s <= 19: return "severo"
        return "extremo"
    if kind == "STR":
        s = score
        if s <= 14: return "normal"
        if s <= 18: return "leve"
        if s <= 25: return "moderado"
        if s <= 33: return "severo"
        return "extremo"
    return "desconocido"

# ------------------------- NEGOCIACIÓN (contención + compromiso) -------------------------
CRISIS_KEYWORDS = ["quiero", "matar", "suic", "autoles", "hacerme daño", "lastimarme", "no quiero vivir"]

def _is_crisis(text: str) -> bool:
    t = text.lower()
    return any(k in t for k in CRISIS_KEYWORDS)

def negotiation_reply(user_msg: str) -> Dict[str, Any]:
    # Mensaje seguro y breve.
    reply = (
        "Gracias por decir cómo te sientes. Tu seguridad importa. "
        "¿Podemos acordar algo ahora mismo? Durante los próximos 30 minutos, "
        "evita cualquier acción que pueda ponerte en riesgo. Respira: inhala 4, sostén 4, exhala 6. "
        "Si hay peligro inmediato, contacta al 911 o a la Línea de la Vida 800-911-2000. "
        "¿Te parece si seguimos conversando mientras te acompaño?"
    )
    agreement_prompt = "¿Aceptas este plan de 30 minutos seguros?"
    return {"message": reply, "ask_commitment": True, "commitment_question": agreement_prompt}

# ------------------------- EEA PASOS -------------------------
EEA_STEPS = {
    "eleccion_del_evento":      "**Elección del evento**: identifica una situación reciente que te movió emocionalmente (tristeza, ansiedad, enojo, pérdida, etc.). Describe brevemente qué ocurrió.",
    "escritura_libre":          "**Escritura libre**: redacta sin censura lo que piensas y sientes sobre ese evento. No te preocupes por la forma; enfócate en vaciar la mente.",
    "exploracion_emocional":    "**Exploración emocional**: pon en palabras emociones, pensamientos automáticos y reacciones corporales que notaste. Sé específico/a.",
    "reencuadre_autoreflexivo": "**Reencuadre autoreflexivo**: ¿Qué aprendizajes, alternativas o significados ves ahora? ¿Qué te dirías con amabilidad?",
    "cierre_positivo":          "**Cierre positivo**: escribe una frase de autocuidado o un plan breve para ti (algo pequeño y concreto que harás hoy)."
}

# ------------------------- ENDPOINTS -------------------------

@router.post("/first-contact/start")
def first_contact_start(payload: StartSessionIn):
    """
    Primer acercamiento: crea sesión y regresa la primera pregunta de DASS-21.
    """
    db = get_db()
    session = {
        "user_id": payload.user_id,
        "channel": payload.channel,
        "created_at": datetime.utcnow(),
        "state": "DASS21",
        "answers": [None] * 21
    }
    res = db.sessions.insert_one(session)
    return {
        "session_id": str(res.inserted_id),
        "flow": "DASS21",
        "question_index": 0,
        "question_text": DASS21_QUESTIONS[0]
    }

@router.get("/dass21/question")
def dass21_question(session_id: str, index: int):
    """
    Obtiene una pregunta específica por índice.
    """
    db = get_db()
    sid = _oid(session_id)
    s = db.sessions.find_one({"_id": sid})
    if not s:
        raise HTTPException(404, "Sesión no encontrada")
    if not (0 <= index < 21):
        raise HTTPException(400, "Índice fuera de rango")
    return {"session_id": session_id, "index": index, "text": DASS21_QUESTIONS[index]}

@router.post("/dass21/answer")
def dass21_answer(payload: DassAnswerIn):
    """
    Guarda respuesta. Si completa 21, devuelve puntajes y severidades.
    """
    db = get_db()
    sid = _oid(payload.session_id)
    s = db.sessions.find_one({"_id": sid})
    if not s:
        raise HTTPException(404, "Sesión no encontrada")

    answers = s.get("answers", [None] * 21)
    if not (0 <= payload.index < 21):
        raise HTTPException(400, "Índice fuera de rango")
    answers[payload.index] = payload.value
    db.sessions.update_one({"_id": sid}, {"$set": {"answers": answers}})

    # siguiente
    try:
        next_idx = answers.index(None)
        return {
            "done": False,
            "next_index": next_idx,
            "next_text": DASS21_QUESTIONS[next_idx]
        }
    except ValueError:
        # completo
        vals = [int(v) for v in answers]
        dep = _sum_items(vals, DEP_IDX) * 2
        anx = _sum_items(vals, ANX_IDX) * 2
        str_ = _sum_items(vals, STR_IDX) * 2
        result = {
            "depresion": {"score": dep, "severity": _severity(dep, "DEP")},
            "ansiedad":  {"score": anx, "severity": _severity(anx, "ANX")},
            "estres":    {"score": str_, "severity": _severity(str_, "STR")},
        }
        db.sessions.update_one(
            {"_id": sid},
            {"$set": {"state": "NEGOTIATION", "dass21_result": result}}
        )
        return {"done": True, "scores": result, "next_flow": "NEGOTIATION"}

@router.post("/negotiation/message")
def negotiation_message(payload: NegotiationIn):
    """
    Lógica de negociación de seguridad: contención + petición de compromiso breve.
    Guarda interacción.
    """
    db = get_db()
    sid = _oid(payload.session_id)
    s = db.sessions.find_one({"_id": sid})
    if not s:
        raise HTTPException(404, "Sesión no encontrada")

    crisis = _is_crisis(payload.user_message)
    out = negotiation_reply(payload.user_message)

    db.interactions.insert_one({
        "session_id": sid,
        "type": "negotiation",
        "user_message": payload.user_message,
        "bot_message": out["message"],
        "crisis_detected": crisis,
        "created_at": datetime.utcnow()
    })

    return {"crisis_detected": crisis, **out}

@router.post("/eea/step")
def eea_step(payload: EeaStepIn):
    """
    Entrega el prompt del paso EEA solicitado y guarda la respuesta del usuario.
    """
    db = get_db()
    sid = _oid(payload.session_id)
    s = db.sessions.find_one({"_id": sid})
    if not s:
        raise HTTPException(404, "Sesión no encontrada")

    step = EEA_STEPS.get(payload.step_key)
    if not step:
        raise HTTPException(400, "step_key inválido")

    db.eea_entries.insert_one({
        "session_id": sid,
        "step_key": payload.step_key,
        "user_text": payload.user_text,
        "created_at": datetime.utcnow()
    })

    return {
        "step_key": payload.step_key,
        "step_prompt": step,
        "saved": True
    }

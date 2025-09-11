# app/routes/ai.py
# Router FastAPI para IA: Ollama (chat) + OpenAI (náhuatl, TTS)
import os, re, time, base64, requests, logging
from typing import Tuple, Any
from fastapi import APIRouter, Query, HTTPException
from unidecode import unidecode
from openai import OpenAI

# pip install -U langchain-ollama
from langchain_ollama import OllamaLLM

# Conexión Mongo compartida
from ..db.mongo import get_db
from bson.objectid import ObjectId  # ✅ validar/convertir el sid

router = APIRouter()
log = logging.getLogger("uvicorn.info")

# ------------------- Config -------------------
OLLAMA_HOST   = os.getenv("OLLAMA_HOST", "http://127.0.0.1:11434")
MODEL_DEFAULT = os.getenv("OLLAMA_MODEL", "llama3.1:8b")
OPENAI_KEY    = os.getenv("OPENAI_API_KEY", "")

TEMPERATURE_DEFAULT = float(os.getenv("LLM_TEMPERATURE", "0.5"))
TOP_P_DEFAULT       = float(os.getenv("LLM_TOP_P", "0.5"))

# Memoria por sesión
MEMORY_MAX_TURNS = 10  # pares user/assistant a conservar

# ------------------- Guardrails -------------------
banned_terms = [
    "suicidio","suicidarme","suicidarse","suicidios","suicidio asistido",
    "quitarme la vida","me quiero matar","me mato","matarme","matarme ahora",
    "asesinarme","hacerme daño","autolesion","autolesión","autolesionarme",
    "lastimarme","me quiero lastimar","ahorcarme","cortarme",
    "cortarse las venas","cortar las venas","envenenarme","ideación suicida",
    "ideacion suicida","ideación suicida pasiva","deseo de estar muerto",
    "desesperanza","falta de propósito","sentirse atrapado","retiro social",
    "cambios de ánimo","comportamiento imprudente","cortarse / cortes",
    "quemarse","autolesión / lesión auto-infligida","automutilación"
]

REFUSAL_PATTERNS = [
    r"\blo siento,\s*pero\s*no puedo\b",
    r"\bno puedo continuar\b",
    r"\bno puedo cumplir\b",
    r"\bno puedo ayudar\b",
    r"\bno puedo ofrecer\b",
    r"\bno puedo generar\b",
    r"\bno puedo hablar\b",
]

def normalize(txt: str) -> str:
    return re.sub(r"\s+", " ", unidecode(txt.lower())).strip()

def contains_banned(text: str) -> bool:
    norm = normalize(text)
    banned_norm = [normalize(t) for t in banned_terms]
    return any(t in norm for t in banned_norm)

def contains_refusal(text: str) -> bool:
    t = normalize(text)
    return any(re.search(pat, t, flags=re.IGNORECASE) for pat in REFUSAL_PATTERNS)

def make_llm(model_name: str, temperature: float, top_p: float):
    return OllamaLLM(
        model=model_name,
        base_url=OLLAMA_HOST,
        temperature=temperature,
        top_p=top_p,
    )

def safe_generate(llm, prompt: str, max_retries=3) -> Tuple[str, float, int, bool]:
    """
    Reintenta si el modelo usa términos prohibidos o frases de rechazo.
    Devuelve: (texto, tiempo, intentos, flagged)
    """
    out, dur = "", 0.0
    for attempt in range(1, max_retries + 1):
        start = time.time()
        out = llm.invoke(prompt)
        dur = round(time.time() - start, 4)
        log.info(f"[AI attempt {attempt}] out={out!r}")

        if not contains_banned(out) and not contains_refusal(out):
            return out.strip(), dur, attempt, False

        # Refuerzo de reglas si falló
        prompt += (
            "\n\nREGLA ESTRICTA:\n"
            "- No uses frases de rechazo como 'no puedo...' ni negativas similares.\n"
            "- Evita por completo términos de autolesión/suicidio.\n"
            "- Si el tema es sensible, contiene con empatía, ofrece un micro-paso seguro y termina con una pregunta breve.\n"
            "- Mantén el español, cálido y respetuoso.\n"
        )
    return out.strip(), dur, max_retries, True

# ------------------- Memoria en Mongo -------------------
def _ensure_sid(sid: str) -> Any:
    """
    Valida el sid, lo convierte a ObjectId y verifica que exista una sesión.
    Soporta 'sessions' y (opcional) 'flow_sessions'.
    """
    sid = (sid or "").strip()
    if not sid:
        raise HTTPException(400, "sid faltante")

    try:
        oid = ObjectId(sid)
    except Exception:
        raise HTTPException(400, "sid inválido")

    db = get_db()
    session_doc = (
        db.get_collection("sessions").find_one({"_id": oid})
        or db.get_collection("flow_sessions").find_one({"_id": oid})
    )
    if not session_doc:
        raise HTTPException(404, "Sesión no encontrada")

    return oid

def _append_memory(sid_oid, role: str, text: str):
    db = get_db()
    db.get_collection("ai_messages").insert_one({
        "session_id": sid_oid,
        "role": role,            # "user" / "assistant"
        "text": text,
        "ts": time.time(),
    })
    # Recortar memoria a los últimos MEMORY_MAX_TURNS*2 mensajes
    msgs = list(db.get_collection("ai_messages")
                  .find({"session_id": sid_oid})
                  .sort("ts", 1))
    excess = max(0, len(msgs) - (MEMORY_MAX_TURNS * 2))
    if excess > 0:
        ids_to_delete = [m["_id"] for m in msgs[:excess]]
        db.get_collection("ai_messages").delete_many({"_id": {"$in": ids_to_delete}})

def _get_memory_text(sid_oid, max_turns: int = MEMORY_MAX_TURNS) -> str:
    """
    Devuelve un bloque de contexto plano con los últimos turnos user/assistant.
    """
    if not sid_oid:
        return ""
    db = get_db()
    cur = db.get_collection("ai_messages").find({"session_id": sid_oid}).sort("ts", 1)
    msgs = [{"role": m["role"], "text": m["text"]} for m in cur]
    msgs = msgs[-max_turns*2:]
    lines = []
    for m in msgs:
        prefix = "Usuario:" if m["role"] == "user" else "Asistente:"
        lines.append(f"{prefix} {m['text']}")
    return "\n".join(lines)

# ------------------- Prompts -------------------
TEMPLATE_SALUDO = """
{lang_prefix}
Genera un ÚNICO saludo en el idioma indicado (30–70 palabras).
Tono: cercano, cálido y claro. NO uses Markdown. Incluye que eres CoralIA.
No repitas frases de relleno.

Memoria (resumen de últimos turnos):
{memoria}

REGLA DE SEGURIDAD:
No menciones términos de autolesión/suicidio:
{lista_prohibidas}

REGLA ANTI-RECHAZO:
Nunca uses negativas del tipo "no puedo..." ni similares.

Contexto: Bienvenida para {name}; enfócate solo en saludar a {name}.
"""

TEMPLATE_RESPUESTAS = """
{lang_prefix}
Actúa como acompañante emocional breve y empático. Responde en 1–3 frases, sin Markdown.
Adáptate exactamente al mensaje. Si hace una pregunta, respóndela primero y añade un micro-paso práctico
(respiración corta, anclaje, o sugerir hablar con alguien de confianza).
Termina con una pregunta abierta breve para continuar la conversación.

Memoria (últimos turnos):
{memoria}

REGLA DE SEGURIDAD:
No menciones términos de autolesión/suicidio:
{lista_prohibidas}

REGLA ANTI-RECHAZO:
Nunca uses negativas del tipo "no puedo..." ni similares.

Contexto y mensaje actual: {contexto}
"""

TEMPLATE_MINDFULLNESS = """
{lang_prefix}
Genera un ejercicio breve de mindfulness con lista numerada (≥ 4 pasos).
20–70 palabras por ejercicio. Sin enlaces.

Memoria resumida:
{memoria}

REGLA DE SEGURIDAD:
No menciones términos de autolesión/suicidio:
{lista_prohibidas}

Contexto: {contexto}
"""

TEMPLATE_DASS21 = """
{lang_prefix}
Genera las 21 preguntas del DASS-21 separadas por saltos de línea, sin encabezados ni enlaces.
No incluyas el nombre de CoralIA.

REGLA DE SEGURIDAD:
No menciones términos de autolesión/suicidio:
{lista_prohibidas}

Contexto: {contexto}
"""

TEMPLATE_EEA = """
{lang_prefix}
Genera SOLO UN paso del ejercicio de escritura emocional autoreflexiva (EEA) (20–70 palabras),
usa **negritas** al inicio si el idioma lo permite.

REGLA DE SEGURIDAD:
No menciones términos de autolesión/suicidio:
{lista_prohibidas}

Contexto: {contexto}
"""

def is_crisis_input(text: str) -> bool:
    return contains_banned(text)

def crisis_reply(name: str) -> str:
    return (
        f"{name}, gracias por decir cómo te sientes. Tu seguridad importa. "
        "Si hay peligro inmediato, busca apoyo de alguien de confianza o contacta a emergencias. "
        "Hagamos una respiración: inhala 4, sostén 4, exhala 6. Estoy aquí para acompañarte. "
        "¿Qué está pasando justo ahora?"
    )

# ------------------- OpenAI helpers (traducción/voz) -------------------
def require_openai() -> OpenAI:
    if not OPENAI_KEY:
        raise HTTPException(status_code=400, detail="Falta OPENAI_API_KEY en variables de entorno.")
    return OpenAI(api_key=OPENAI_KEY)

def translate_es_to_nah(text: str) -> str:
    """
    Traduce español → náhuatl preservando estructura y longitud relativa.
    - No resume ni agrega.
    - Conserva saltos de línea, viñetas/numeración, signos, emojis y **negritas**/*itálicas*.
    - Reintenta si el resultado es demasiado corto.
    """
    try:
        client = require_openai()

        def _ask(prompt_text: str, harder: bool = False) -> str:
            system = (
                "Eres traductor español a náhuatl (variante central). "
                "TRADUCE palabra por palabra :\n"
                "- El número de oraciones en cada párrafo.\n"
                "- Los saltos de línea, viñetas y numeración (1., 2., •, -).\n"
                "- Los signos, emojis y el formato **negritas** y *itálicas* si existen.\n"
                "No agregues notas. Si no hay equivalente, deja el término en español entre [ ]."
            )
            if harder:
                system += (
                    "\nMUY IMPORTANTE: Mantén fidelidad de la traduccion por cada palabra. "
                    "No reescribas en estilo telegráfico."
                )
            user = (
                "Traduce al náhuatl preservando estructura el bloque siguiente "
                f"{prompt_text}\n"
            )
            chat = client.chat.completions.create(
                model="gpt-4o-mini",
                temperature=0.7,
                messages=[
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
            )
            return (chat.choices[0].message.content or "").strip()

        out = _ask(text, harder=False)

        # Si quedó demasiado corto (<60% del texto fuente), reintenta con reglas más duras
        try:
            if len(out) < max(1, int(len(text) * 0.6)):
                out2 = _ask(text, harder=True)
                if len(out2) > len(out) * 0.9:  # aceptamos si mejora
                    out = out2
        except Exception:
            pass

        return out if out else text

    except Exception as e:
        log.warning(f"[translate_es_to_nah] fallback by error: {e}")
        return text


def maybe_translate(text: str, lang: str) -> str:
    lang = (lang or "es-MX").lower()
    if lang in ("nah", "nhe", "nhi", "nch", "nahuatl"):
        return translate_es_to_nah(text)
    return text

def prefix_lang_instruction(lang: str) -> str:
    lang = (lang or "es-MX").lower()
    if lang in ("nah", "nhe", "nhi", "nch", "nahuatl"):
        return ("Responde en náhuatl (variante central) de forma natural y clara. "
                "Si el mensaje viene en español, respóndelo en náhuatl. ")
    return "Responde en español mexicano. "

# ------------------- Endpoints de salud/diagnóstico -------------------
@router.get("/ping")
def ping():
    return {"ok": True, "model_default": MODEL_DEFAULT, "ollama_host": OLLAMA_HOST}

@router.get("/debug/ollama")
def debug_ollama():
    try:
        r = requests.get(f"{OLLAMA_HOST}/api/tags", timeout=3)
        return {"ok": True, "status": r.status_code, "body": r.json()}
    except Exception as e:
        return {"ok": False, "error": str(e), "host": OLLAMA_HOST}

@router.get("/memory")
def memory(sid: str = Query(...)):
    """Debug: ver memoria usada en la sesión."""
    sid_oid = _ensure_sid(sid)
    txt = _get_memory_text(sid_oid, MEMORY_MAX_TURNS)
    return {"sid": sid, "memory": txt}

# ------------------- Endpoints IA (Ollama) -------------------
@router.get("/saludos")
def saludos(
    name: str = Query("Invitado"),
    sid: str | None = Query(None),
    model: str | None = Query(None),
    temp: float | None = Query(None),
    topp: float | None = Query(None),
    lang: str = Query("es-MX"),
):
    sid_oid = None
    memoria = ""
    if sid:
        sid_oid = _ensure_sid(sid)
        memoria = _get_memory_text(sid_oid)

    prompt = TEMPLATE_SALUDO.format(
        lang_prefix=prefix_lang_instruction(lang),
        lista_prohibidas=", ".join(banned_terms),
        memoria=memoria or "(sin mensajes previos)",
        name=name,
    )

    model_name = model or MODEL_DEFAULT
    temperature = float(temp) if temp is not None else TEMPERATURE_DEFAULT
    topp = float(topp) if topp is not None else TOP_P_DEFAULT

    try:
        llm = make_llm(model_name, temperature, topp)
        texto, t, n, flagged = safe_generate(llm, prompt)
        texto_out = maybe_translate(texto, lang)  # 🔁 traducir si es náhuatl

        if sid_oid:
            _append_memory(sid_oid, "assistant", texto_out)
        return {
            "persona": name, "modelo": model_name,
            "respuesta": texto_out, "tiempo": t, "intentos": n,
            "flagged": flagged, "lang": lang
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ollama error: {e}")

@router.get("/respuestas")
def respuestas(
    name: str = Query("Invitado"),
    interaccion: str = Query("¿Cómo estás?"),
    sid: str | None = Query(None),
    model: str | None = Query(None),
    temp: float | None = Query(None),
    topp: float | None = Query(None),
    lang: str = Query("es-MX"),
):
    sid_oid = None
    if sid:
        sid_oid = _ensure_sid(sid)
        _append_memory(sid_oid, "user", interaccion)

    # Detección de crisis en la ENTRADA
    if is_crisis_input(interaccion):
        crisis_text = crisis_reply(name)
        crisis_text = maybe_translate(crisis_text, lang)
        if sid_oid:
            _append_memory(sid_oid, "assistant", crisis_text)
        return {
            "persona": name, "modelo": model or MODEL_DEFAULT,
            "respuesta": crisis_text, "crisis": True, "lang": lang
        }

    memoria = _get_memory_text(sid_oid, MEMORY_MAX_TURNS) if sid_oid else ""
    context = f"Nombre: {name}. Mensaje: {interaccion}"

    prompt = TEMPLATE_RESPUESTAS.format(
        lang_prefix=prefix_lang_instruction(lang),
        lista_prohibidas=", ".join(banned_terms),
        memoria=memoria or "(sin historial en esta sesión)",
        contexto=context
    )

    model_name = model or MODEL_DEFAULT
    temperature = float(temp) if temp is not None else max(0.7, TEMPERATURE_DEFAULT)
    topp = float(topp) if topp is not None else max(0.85, TOP_P_DEFAULT)

    try:
        llm = make_llm(model_name, temperature, topp)
        texto, t, n, flagged = safe_generate(llm, prompt)
        texto_out = maybe_translate(texto, lang)  # 🔁 traducir si es náhuatl

        if sid_oid:
            _append_memory(sid_oid, "assistant", texto_out)
        return {
            "persona": name, "modelo": model_name,
            "respuesta": texto_out, "tiempo": t, "intentos": n,
            "flagged": flagged, "crisis": False, "lang": lang
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ollama error: {e}")

@router.get("/mindfullness")
def mindfullness(
    name: str = Query("Invitado"),
    interaccion: str = Query("Necesito un ejercicio de mindfulness para relajarme."),
    sid: str | None = Query(None),
    model: str | None = Query(None),
    temp: float | None = Query(None),
    topp: float | None = Query(None),
    lang: str = Query("es-MX"),
):
    sid_oid = None
    memoria = ""
    if sid:
        sid_oid = _ensure_sid(sid)
        _append_memory(sid_oid, "user", interaccion)
        memoria = _get_memory_text(sid_oid)

    context = f"Genera un ejercicio enumerado (≥4 pasos) para {name}; acorde a: {interaccion}."
    prompt = TEMPLATE_MINDFULLNESS.format(
        lang_prefix=prefix_lang_instruction(lang),
        lista_prohibidas=", ".join(banned_terms),
        memoria=memoria or "(sin historial en esta sesión)",
        contexto=context
    )

    model_name = model or MODEL_DEFAULT
    temperature = float(temp) if temp is not None else TEMPERATURE_DEFAULT
    topp = float(topp) if topp is not None else TOP_P_DEFAULT

    try:
        llm = make_llm(model_name, temperature, topp)
        texto, t, n, flagged = safe_generate(llm, prompt)
        texto_out = maybe_translate(texto, lang)

        if sid_oid:
            _append_memory(sid_oid, "assistant", texto_out)
        return {
            "persona": name, "modelo": model_name,
            "respuesta": texto_out, "tiempo": t, "intentos": n,
            "flagged": flagged, "lang": lang
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ollama error: {e}")

@router.get("/eea")
def eea(
    name: str = Query("Invitado"),
    paso: str = Query("Elección del evento"),
    sid: str | None = Query(None),
    model: str | None = Query(None),
    temp: float | None = Query(None),
    topp: float | None = Query(None),
    lang: str = Query("es-MX"),
):
    sid_oid = None
    memoria = ""
    if sid:
        sid_oid = _ensure_sid(sid)
        memoria = _get_memory_text(sid_oid)

    context = f"Genera el texto del paso EEA para {name}; el paso es: {paso}."
    prompt = TEMPLATE_EEA.format(
        lang_prefix=prefix_lang_instruction(lang),
        lista_prohibidas=", ".join(banned_terms),
        contexto=context
    )

    model_name = model or MODEL_DEFAULT
    temperature = float(temp) if temp is not None else TEMPERATURE_DEFAULT
    topp = float(topp) if topp is not None else TOP_P_DEFAULT

    try:
        llm = make_llm(model_name, temperature, topp)
        texto, t, n, flagged = safe_generate(llm, prompt)
        texto_out = maybe_translate(texto, lang)

        if sid_oid:
            _append_memory(sid_oid, "assistant", texto_out)
        return {
            "persona": name, "modelo": model_name, "respuesta": texto_out,
            "tiempo": t, "intentos": n, "flagged": flagged, "lang": lang
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ollama error: {e}")

@router.get("/dass21")
def dass21(
    name: str = Query("Invitado"),
    sid: str | None = Query(None),
    model: str | None = Query(None),
    temp: float | None = Query(None),
    topp: float | None = Query(None),
    lang: str = Query("es-MX"),
):
    # Aceptamos sid para evitar 400 aunque no se use
    if sid:
        _ensure_sid(sid)

    context = f"Genera las preguntas del DASS-21 para {name}; separadas por salto de línea; no incluyas CoralIA."
    prompt = TEMPLATE_DASS21.format(
        lang_prefix=prefix_lang_instruction(lang),
        lista_prohibidas=", ".join(banned_terms),
        contexto=context
    )

    model_name = model or MODEL_DEFAULT
    temperature = float(temp) if temp is not None else TEMPERATURE_DEFAULT
    topp = float(topp) if topp is not None else TOP_P_DEFAULT

    try:
        llm = make_llm(model_name, temperature, topp)
        texto, t, n, flagged = safe_generate(llm, prompt)
        texto_out = maybe_translate(texto, lang)
        return {
            "persona": name, "modelo": model_name,
            "respuesta": texto_out, "tiempo": t, "intentos": n,
            "flagged": flagged, "lang": lang
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ollama error: {e}")

# ------------------- OpenAI: traducción y TTS -------------------
@router.get("/nahuatl")
def nahuatl(texto: str = Query(..., description="Texto en español a traducir")):
    client = require_openai()
    chat = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "Eres un asistente de traducción de español a náhuatl (variante central). Devuelve solo la traducción."},
            {"role": "user", "content": texto}
        ],
        temperature=0.4
    )
    return {"traduccion": chat.choices[0].message.content}

@router.get("/genera_voz")
def genera_voz(
    prompt: str = Query(..., description="Texto a sintetizar"),
    lang: str = Query("alloy", description="Voz (alloy, verse, shimmer, etc.)")
):
    client = require_openai()
    speech = client.audio.speech.create(
        model="gpt-4o-mini-tts",  # o "tts-1"
        voice=lang,
        input=prompt
    )
    audio_b64 = base64.b64encode(speech.read()).decode("utf-8")
    return {"audio_b64": audio_b64, "format": "mp3"}

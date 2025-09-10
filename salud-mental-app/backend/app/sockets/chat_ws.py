"""
Gestor de conexiones WebSocket para chat.
- Mantiene mapa de clientes.
- Emite respuestas simples (placeholder) y corta en crisis.
"""
from typing import Dict
from fastapi import WebSocket, WebSocketDisconnect
from ..services.chatbot_service import text_to_flags

class ConnectionManager:
    def __init__(self) -> None:
        self.active: Dict[str, WebSocket] = {}

    async def connect(self, user_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        self.active[user_id] = websocket

    def disconnect(self, user_id: str) -> None:
        self.active.pop(user_id, None)

    async def send_to(self, user_id: str, message: str) -> None:
        ws = self.active.get(user_id)
        if ws:
            await ws.send_text(message)

manager = ConnectionManager()

async def handle_message(user_id: str, text: str) -> str:
    """
    Placeholder: aplica guardrails básicos.
    - Si hay ideación explícita → corta y deriva a SOS.
    - Si hay desesperanza → contención breve y sugerir ayuda.
    En producción: integrar LangChain + modelo (Ollama).
    """
    flags = text_to_flags(text)
    if "explicit_ideation" in flags:
        return "Estoy aquí contigo. Me preocupa tu seguridad. Te ofrezco opciones inmediatas: Botón SOS, llamar 911 o Línea de la Vida (800 911 2000)."
    if "hopelessness" in flags:
        return "Siento que estés pasando por esto. ¿Te parece si hacemos una respiración 4-4-6 y luego vemos opciones de apoyo profesional?"
    return "Te leo. Gracias por compartir. ¿Quieres contarme un poco más de cómo te sientes ahora mismo?"

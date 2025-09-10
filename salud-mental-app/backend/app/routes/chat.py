from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from ..core.deps import current_user  # solo para HTTP; para WS haremos token query
from ..sockets.chat_ws import manager, handle_message

router = APIRouter()

@router.websocket("/ws")
async def chat_ws(websocket: WebSocket):
    """
    WebSocket de chat.
    Autenticación simple por query param ?user_id=<email> (MVP).
    En producción: firma de token y validación robusta.
    """
    user_id = websocket.query_params.get("user_id")
    if not user_id:
        await websocket.close(code=4401)  # Unauthorized
        return

    await manager.connect(user_id, websocket)
    try:
        await manager.send_to(user_id, "Hola, estoy contigo. ¿Qué quisieras compartir?")
        while True:
            text = await websocket.receive_text()
            reply = await handle_message(user_id, text)
            await manager.send_to(user_id, reply)
    except WebSocketDisconnect:
        manager.disconnect(user_id)

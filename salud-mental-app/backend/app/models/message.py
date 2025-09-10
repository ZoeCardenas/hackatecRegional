"""
Registro de mensajes (para trazabilidad).
En producción: aplica redacción de PII y retención limitada.
"""
from datetime import datetime
from pydantic import BaseModel
from motor.motor_asyncio import AsyncIOMotorDatabase

class MessageLog(BaseModel):
    convo_id: str
    sender: str  # 'user' | 'bot' | 'therapist'
    text: str
    ts: datetime

class MessageRepo:
    def __init__(self, db: AsyncIOMotorDatabase) -> None:
        self.col = db["messages"]

    async def append(self, item: MessageLog) -> str:
        d = item.model_dump()
        res = await self.col.insert_one(d)
        return str(res.inserted_id)

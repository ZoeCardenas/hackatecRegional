"""
Alertas de riesgo/SOS.
"""
from datetime import datetime
from typing import Literal
from pydantic import BaseModel
from motor.motor_asyncio import AsyncIOMotorDatabase

Severity = Literal["low","med","high","critical"]

class AlertCreate(BaseModel):
    user_id: str
    type: Literal["sos","risk"]
    severity: Severity
    channels: list[str] = []

class AlertRepo:
    def __init__(self, db: AsyncIOMotorDatabase) -> None:
        self.col = db["alerts"]

    async def create(self, data: AlertCreate) -> str:
        doc = {**data.model_dump(), "created_at": datetime.utcnow()}
        res = await self.col.insert_one(doc)
        return str(res.inserted_id)

# app/models/assessment.py
"""
Schemas DASS-21 y repo.
Incluye scoring en service separado (mejor testeable).
"""
from datetime import datetime, timezone
from typing import Literal
from pydantic import BaseModel, Field
from anyio import to_thread


class Dass21Submit(BaseModel):
    # 21 respuestas escala 0..3
    answers: list[int] = Field(min_length=21, max_length=21)


class Dass21Score(BaseModel):
    D: int
    A: int
    S: int
    total: int
    risk_level: Literal[0, 1, 2, 3]


class AssessmentRepo:
    def __init__(self, db) -> None:
        self.col = db["assessments"]

    async def save(self, user_id: str, score: Dass21Score) -> str:
        doc = {
            "user_id": user_id,
            "type": "DASS21",
            "score": score.model_dump(),
            "created_at": datetime.now(timezone.utc),
        }

        def _insert():
            res = self.col.insert_one(doc)
            return str(res.inserted_id)

        return await to_thread.run_sync(_insert)

    async def history(self, user_id: str, limit: int = 6) -> list[dict]:
        def _fetch():
            cur = self.col.find({"user_id": user_id}).sort("created_at", -1).limit(limit)
            return [{**d, "_id": str(d["_id"])} for d in cur]

        return await to_thread.run_sync(_fetch)

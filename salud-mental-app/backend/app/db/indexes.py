# backend/app/db/indexes.py
"""
Creación de índices de forma asíncrona.
"""
from pymongo import ASCENDING

async def ensure_indexes(db):
    # users
    await db["users"].create_index([("email", ASCENDING)], unique=True)

    # therapists: reemplaza índice viejo por uno PARCIAL (solo cuando email es string)
    try:
        await db["therapists"].drop_index("email_1")
    except Exception:
        pass
    await db["therapists"].create_index(
        [("email", ASCENDING)],
        unique=True,
        partialFilterExpression={"email": {"$type": "string"}},
    )

    # appointments
    await db["appointments"].create_index([("user_id", ASCENDING), ("start", ASCENDING)])

    # messages / alerts / content
    await db["messages"].create_index([("user_id", ASCENDING), ("created_at", -1)])
    await db["alerts"].create_index([("user_id", ASCENDING), ("created_at", -1)])
    await db["content"].create_index([("key", ASCENDING)], unique=True)

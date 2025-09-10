# app/db/mongo.py
import os
from pymongo import MongoClient

_client = None
_db = None

def connect_to_mongo():
    """
    Conecta a Mongo y crea índices. Lee MONGO_URI y MONGO_DB de env.
    Se llama en startup (lifespan) y es SINCRÓNICO.
    """
    global _client, _db
    if _client:
        return _db

    uri = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
    dbname = os.environ.get("MONGO_DB", "salud_mental")

    _client = MongoClient(uri, uuidRepresentation="standard")
    _db = _client[dbname]

    # ---- ÍNDICES ----

    # users: email único
    _db.users.create_index("email", unique=True)

    # therapists: queremos único solo cuando email es string (parcial).
    # si existe un índice previo "email_1" no parcial, lo intentamos borrar
    try:
        _db.therapists.drop_index("email_1")
    except Exception:
        pass
    _db.therapists.create_index(
        [("email", 1)],
        unique=True,
        partialFilterExpression={"email": {"$type": "string"}}
    )

    # appointments: consulta rápida por usuario + when
    _db.appointments.create_index([("user_id", 1), ("when", 1)])

    return _db


def disconnect_from_mongo():
    """
    Cierra la conexión. Si la DB se llama salud_mental_test_*, la borra.
    """
    global _client, _db
    if _client:
        dbname = os.environ.get("MONGO_DB", "")
        if dbname.startswith("salud_mental_test_"):
            _client.drop_database(dbname)
        _client.close()
    _client = None
    _db = None


def get_db():
    if _db is None:
        raise RuntimeError("MongoDB no inicializado. Llama connect_to_mongo() en startup.")
    return _db

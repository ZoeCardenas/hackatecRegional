"""
Configuración central de la app (fuente única de verdad).
Lee variables de entorno y expone un objeto Settings tipado.
"""
import os
from pydantic import BaseModel, Field

class Settings(BaseModel):
    MONGO_URI: str = Field(default_factory=lambda: os.getenv("MONGO_URI", "mongodb://localhost:27017"))
    MONGO_DB: str  = Field(default_factory=lambda: os.getenv("MONGO_DB", "salud_mental"))
    JWT_SECRET: str = Field(default_factory=lambda: os.getenv("JWT_SECRET", "changeme"))
    JWT_EXPIRES_MIN: int = Field(default_factory=lambda: int(os.getenv("JWT_EXPIRES_MIN", "60")))
    CORS_ORIGINS: list[str] = Field(default_factory=lambda: ["*"])
    CONTENT_DIR: str = Field(default_factory=lambda: os.getenv("CONTENT_DIR", "../../content"))

settings = Settings()

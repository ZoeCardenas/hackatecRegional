"""
Configuración de logging estructurado.
- Nivel INFO por defecto; DEBUG en desarrollo.
- Formato con timestamps y nombre del logger.
- Integra con Uvicorn (hereda handlers) para no duplicar.
"""
import logging
import os

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()

def setup_logging() -> None:
    logging.basicConfig(
        level=LOG_LEVEL,
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    )
    # Ajusta loggers de uvicorn para no duplicar formato
    for uv_logger in ("uvicorn", "uvicorn.error", "uvicorn.access"):
        logging.getLogger(uv_logger).setLevel(LOG_LEVEL)

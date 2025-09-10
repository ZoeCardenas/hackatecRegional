"""
Flujo de respuesta en crisis.
- Mensaje corto, sin detalles de autolesión.
- Ofrece opciones claras y derivación inmediata.
"""
from typing import Final

OPENING: Final[str] = (
    "Gracias por decirlo. Tu seguridad es lo más importante ahora. Estoy aquí contigo."
)

ACTION_LIST: Final[str] = (
    "Puedo: (1) Mostrar el botón SOS para asistencia inmediata, "
    "(2) Llamar a 911 o a la Línea de la Vida (800 911 2000), "
    "(3) Enviarte un ejercicio breve de respiración para estabilizarnos mientras conectamos ayuda, "
    "(4) Avisar a tu terapeuta si lo autorizas."
)

def crisis_response(_user_text: str) -> str:
    """
    Devuelve un texto breve de de-escalado + opciones.
    """
    return (
        f"{OPENING} Ahora mismo, evitemos entrar en detalles; enfoquémonos en mantenerte a salvo. "
        f"{ACTION_LIST} ¿Cuál opción prefieres?"
    )

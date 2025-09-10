"""
Servicio de líneas de emergencia.
Para MX expone 911 y Línea de la Vida.
Separa para facilitar internacionalización.
"""
from pydantic import BaseModel

class EmergencyResponse(BaseModel):
    emergency_numbers: list[str]
    next_steps: list[str]

def get_mx_emergency() -> EmergencyResponse:
    return EmergencyResponse(
        emergency_numbers=["911", "8009112000"],
        next_steps=["Respiración 4-4-6", "Contactar terapeuta autorizado"]
    )

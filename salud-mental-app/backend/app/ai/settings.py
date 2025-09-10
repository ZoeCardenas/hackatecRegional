"""
Configuración simple del modelo local (Ollama).
"""
import os
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "gemma2:latest")

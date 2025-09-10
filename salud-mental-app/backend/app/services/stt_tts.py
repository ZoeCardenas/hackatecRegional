"""
STT/TTS stub:
- En producción: Whisper local (STT) y TTS (piper/edge-tts/AWS Polly).
- Aquí devolvemos placeholders para mantener contrato.
"""
from pydantic import BaseModel

class Transcription(BaseModel):
    text: str

async def transcribe_audio(b64_audio: str) -> Transcription:
    # TODO: integrar modelo real
    return Transcription(text="[transcripción dummy]")

async def synthesize_tts(text: str) -> bytes:
    # TODO: integrar TTS real → bytes de audio
    return b""

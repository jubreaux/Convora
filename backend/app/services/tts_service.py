"""
Text-to-Speech service using OpenAI TTS API.
Maps DISC personality types to distinct character voices.
"""

import base64
from openai import AsyncOpenAI
from app.config import get_settings


# Map DISC types to OpenAI voice personalities
DISC_VOICE_MAP = {
    "D": "onyx",      # Dominant → authoritative, commanding
    "I": "nova",      # Influential → warm, enthusiastic
    "S": "shimmer",   # Steady → gentle, patient
    "C": "echo",      # Conscientious → measured, analytical
}


async def synthesize_reply(text: str, disc_type: str) -> bytes:
    """
    Synthesize speech using OpenAI TTS API.
    
    Args:
        text: The reply text to synthesize
        disc_type: The client's DISC personality type (D/I/S/C)
    
    Returns:
        Raw MP3 bytes
    
    Raises:
        RuntimeError: If OPENAI_API_KEY is not set or API call fails
        ValueError: If disc_type is invalid
    """
    settings = get_settings()
    
    if not settings.OPENAI_API_KEY:
        raise RuntimeError(
            "OPENAI_API_KEY is not set in environment. "
            "Voice mode requires OpenAI TTS API access."
        )
    
    voice = DISC_VOICE_MAP.get(disc_type, "alloy")
    
    client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
    
    try:
        response = await client.audio.speech.create(
            model="tts-1",
            voice=voice,
            input=text,
        )
        return response.content
    except Exception as e:
        raise RuntimeError(f"TTS synthesis failed: {str(e)}")


def encode_audio_base64(audio_bytes: bytes) -> str:
    """Encode raw audio bytes as base64 string for JSON response."""
    return base64.b64encode(audio_bytes).decode("utf-8")


def decode_audio_base64(audio_b64: str) -> bytes:
    """Decode base64 audio string back to raw bytes (client-side)."""
    return base64.b64decode(audio_b64)

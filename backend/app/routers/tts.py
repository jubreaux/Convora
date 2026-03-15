"""
On-demand TTS synthesis endpoint.
Allows clients to synthesize any text using the user's preferred voice.
"""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from app.models import User
from app.utils import get_current_user
from app.services.tts_service import synthesize_reply, encode_audio_base64

router = APIRouter(prefix="/api/tts", tags=["tts"])


class SynthesizeRequest(BaseModel):
    text: str


class SynthesizeResponse(BaseModel):
    audio_base64: str


@router.post("/synthesize", response_model=SynthesizeResponse)
async def synthesize_text(
    request: SynthesizeRequest,
    current_user: User = Depends(get_current_user),
):
    """Synthesize text to speech using the user's preferred voice (or alloy fallback)."""
    if not request.text.strip():
        raise HTTPException(status_code=400, detail="Text cannot be empty")
    try:
        # Use user's preferred voice; fall back to neutral "alloy" if none set
        audio_bytes = await synthesize_reply(
            request.text,
            disc_type="",
            voice_override=current_user.preferred_voice or "alloy",
        )
        return SynthesizeResponse(audio_base64=encode_audio_base64(audio_bytes))
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e))

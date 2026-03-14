from __future__ import annotations
from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import Optional, List


# ===== Auth Schemas =====
class UserResponse(BaseModel):
    id: int
    email: str
    name: str
    role: str
    created_at: datetime

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse


class UserRegister(BaseModel):
    email: EmailStr
    password: str
    name: str


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    """Schema for updating user details (admin only)."""
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    password: Optional[str] = None  # If provided, will be hashed
    role: Optional[str] = None  # "user" or "admin"


class UserDeleteResponse(BaseModel):
    """Response when a user is soft-deleted."""
    message: str
    user_id: int
    deleted_at: datetime


# ===== Scenario Schemas =====
class PersonalityTemplateResponse(BaseModel):
    id: int
    occupation: str
    recreation: Optional[str] = None
    family: Optional[str] = None
    pets: Optional[str] = None
    transaction_type: str
    buy_criteria: Optional[str] = None
    sell_criteria: Optional[str] = None
    surface_motivation: Optional[str] = None
    hidden_motivation: Optional[str] = None
    timeframe: Optional[str] = None
    red_flags: Optional[str] = None

    class Config:
        from_attributes = True


class TraitSetResponse(BaseModel):
    id: int
    trait_set_number: int
    trait_1: str
    trait_2: str
    trait_3: str

    class Config:
        from_attributes = True


class ScenarioContextResponse(BaseModel):
    id: int
    name: str

    class Config:
        from_attributes = True


class ObjectiveResponse(BaseModel):
    id: int
    label: str
    description: Optional[str] = None
    max_points: int

    class Config:
        from_attributes = True


class ObjectiveCreate(BaseModel):
    label: str
    description: Optional[str] = None
    max_points: int = 10


class ScenarioListResponse(BaseModel):
    """Minimal scenario info for listing (no hidden data)."""
    id: int
    title: str
    disc_type: str
    transaction_type: Optional[str] = None
    is_public: bool
    created_at: datetime

    class Config:
        from_attributes = True


class ScenarioDetailResponse(BaseModel):
    """Full scenario detail (for admin or creator only)."""
    id: int
    title: str
    disc_type: str
    personality_template_id: int
    personality_template: Optional[PersonalityTemplateResponse] = None
    trait_set_id: int
    trait_set: Optional[TraitSetResponse] = None
    scenario_context_id: int
    scenario_context: Optional[ScenarioContextResponse] = None
    ai_system_prompt: str
    is_public: bool
    created_by_user_id: Optional[int] = None
    objectives: List[ObjectiveResponse] = []
    created_at: datetime

    class Config:
        from_attributes = True


class ScenarioCreate(BaseModel):
    title: str
    disc_type: str  # "D", "I", "S", "C"
    personality_template_id: int
    trait_set_id: int
    scenario_context_id: int
    ai_system_prompt: str
    objectives: List[ObjectiveCreate]


# ===== Session Schemas =====
class MessageResponse(BaseModel):
    id: int
    role: str
    content: str
    created_at: datetime

    class Config:
        from_attributes = True


class SessionObjectiveResponse(BaseModel):
    id: int
    objective: ObjectiveResponse
    achieved: bool
    points_awarded: int
    notes: Optional[str] = None
    achieved_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class SessionCreateRequest(BaseModel):
    scenario_id: int


class SessionMessageRequest(BaseModel):
    message: str
    voice: bool = False  # If true, send synthesized audio response


class SessionMessageResponse(BaseModel):
    reply: str
    current_score: int
    max_score: int
    objectives_completed: List[SessionObjectiveResponse]
    appointment_set: bool
    audio_base64: Optional[str] = None  # MP3 audio encoded as base64 (if voice=True)


class SessionEndResponse(BaseModel):
    final_score: int
    personality: PersonalityTemplateResponse
    trait_set: TraitSetResponse
    disc_type: str
    objectives: List[SessionObjectiveResponse]
    messages: List[MessageResponse]
    appointment_set: bool

    class Config:
        from_attributes = True


class SessionResponse(BaseModel):
    id: int
    user_id: int
    scenario_id: int
    status: str
    score: int
    appointment_set: bool
    started_at: datetime
    ended_at: Optional[datetime] = None
    messages: List[MessageResponse]

    class Config:
        from_attributes = True


class SessionHistoryResponse(BaseModel):
    id: int
    scenario_id: int
    scenario_title: str
    status: str
    score: int
    started_at: datetime
    ended_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class SessionScoreEventResponse(BaseModel):
    id: int
    event_type: str
    points: int
    label: Optional[str] = None
    reason: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class SessionReviewResponse(BaseModel):
    """Full session review — returned by GET /sessions/{id}/review."""
    id: int
    scenario_id: int
    scenario_title: str
    status: str
    final_score: int
    appointment_set: bool
    started_at: datetime
    ended_at: Optional[datetime] = None
    disc_type: str
    personality: PersonalityTemplateResponse
    trait_set: TraitSetResponse
    objectives: List[SessionObjectiveResponse]
    messages: List[MessageResponse]
    score_events: List[SessionScoreEventResponse]

    class Config:
        from_attributes = True

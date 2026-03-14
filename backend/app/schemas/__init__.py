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
    must_reset_password: bool
    org_id: Optional[int] = None  # Set if user is part of an organization
    org_role: Optional[str] = None  # "org_admin", "team_lead", "member" (populated from OrgMember)
    created_at: datetime

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "email": "user@example.com",
                "name": "John Doe",
                "role": "user",
                "must_reset_password": False,
                "org_id": None,
                "org_role": None,
                "created_at": "2024-01-01T12:00:00"
            }
        }


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse


class UserRegister(BaseModel):
    email: EmailStr
    password: str
    name: str
    account_type: str  # "personal" or "company"
    company_name: Optional[str] = None  # Required when account_type="company"


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserSelfUpdate(BaseModel):
    """Schema for user self-service profile updates (name and email only)."""
    name: Optional[str] = None
    email: Optional[EmailStr] = None


class UserPasswordReset(BaseModel):
    """Schema for user password reset."""
    current_password: str
    new_password: str


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


# ===== User Stats Schemas =====
class TimelinePoint(BaseModel):
    """Single data point for score progression chart."""
    session_date: str  # ISO format
    score: int
    scenario_title: str
    disc_type: str


class DiscTypeStats(BaseModel):
    """Stats for a single DISC personality type."""
    session_count: int
    avg_score: float
    best_score: int


class ScenarioPerformance(BaseModel):
    """User's performance in a single scenario."""
    scenario_title: str
    session_count: int
    avg_score: float
    best_score: int


class UserStatsResponse(BaseModel):
    """Comprehensive user statistics — single bundled endpoint."""
    total_sessions: int
    avg_score: float
    best_score: int
    total_objectives_completed: int
    appointment_rate: float  # 0-100
    timeline: List[TimelinePoint]  # Last 30 completed sessions in order
    disc_breakdown: dict[str, DiscTypeStats]  # "D", "I", "S", "C"
    scenario_performance: List[ScenarioPerformance]  # Sorted by avg_score desc


# ===== Organization & Enterprise Schemas =====
class OrgMemberResponse(BaseModel):
    """Org member with user details."""
    id: int
    user_id: int
    org_role: str
    is_active: bool
    joined_at: datetime

    class Config:
        from_attributes = True


class OrganizationResponse(BaseModel):
    """Organization details."""
    id: int
    name: str
    max_seats: Optional[int] = None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class TeamResponse(BaseModel):
    """Team details."""
    id: int
    org_id: int
    name: str
    description: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class TeamMemberResponse(BaseModel):
    """Team member details."""
    id: int
    team_id: int
    user_id: int
    is_team_lead: bool
    joined_at: datetime

    class Config:
        from_attributes = True


class TrainingAssignmentResponse(BaseModel):
    """Training assignment details."""
    id: int
    org_id: int
    team_id: Optional[int] = None
    user_id: Optional[int] = None
    scenario_id: int
    due_date: Optional[datetime] = None
    notes: Optional[str] = None
    assigned_by_user_id: int
    created_at: datetime

    class Config:
        from_attributes = True


class TrainingAssignmentCreate(BaseModel):
    """Request to create a training assignment."""
    scenario_id: int
    team_id: Optional[int] = None  # If set: assign to team
    user_id: Optional[int] = None  # If set (team_id null): assign to individual
    due_date: Optional[datetime] = None
    notes: Optional[str] = None


class OrgMemberCreate(BaseModel):
    """Request to provision a new org member."""
    email: EmailStr
    name: str
    temp_password: str
    org_role: str  # "org_admin", "team_lead", "member"

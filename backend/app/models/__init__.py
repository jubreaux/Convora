from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey, JSON, UniqueConstraint
from sqlalchemy.orm import relationship
from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    name = Column(String(255), nullable=False)
    role = Column(String(50), default="user", nullable=False)  # "user" or "admin"
    must_reset_password = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    is_deleted = Column(Boolean, default=False, nullable=False)

    # Relationships
    scenarios = relationship("Scenario", back_populates="created_by", foreign_keys="Scenario.created_by_user_id")
    sessions = relationship("Session", back_populates="user")
    org_memberships = relationship("OrgMember", back_populates="user", cascade="all, delete-orphan")
    team_memberships = relationship("TeamMember", back_populates="user", cascade="all, delete-orphan")


class PersonalityTemplate(Base):
    __tablename__ = "personality_templates"

    id = Column(Integer, primary_key=True, index=True)
    occupation = Column(String(255), nullable=False)
    recreation = Column(Text, nullable=True)
    family = Column(Text, nullable=True)
    pets = Column(Text, nullable=True)
    transaction_type = Column(String(100), nullable=False)  # "Buy", "Sell", "Sell/Buy", "First time buyer", etc.
    buy_criteria = Column(Text, nullable=True)
    sell_criteria = Column(Text, nullable=True)
    surface_motivation = Column(Text, nullable=True)
    hidden_motivation = Column(Text, nullable=True)
    timeframe = Column(Text, nullable=True)
    red_flags = Column(Text, nullable=True)

    # Relationships
    scenarios = relationship("Scenario", back_populates="personality_template")


class TraitSet(Base):
    __tablename__ = "trait_sets"

    id = Column(Integer, primary_key=True, index=True)
    trait_set_number = Column(Integer, unique=True, nullable=False)
    trait_1 = Column(String(100), nullable=False)
    trait_2 = Column(String(100), nullable=False)
    trait_3 = Column(String(100), nullable=False)

    # Relationships
    scenarios = relationship("Scenario", back_populates="trait_set")


class ScenarioContext(Base):
    __tablename__ = "scenario_contexts"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), unique=True, nullable=False)  # "Open House", "Outbound call, expired", etc.

    # Relationships
    scenarios = relationship("Scenario", back_populates="scenario_context")


class FinetuneExample(Base):
    __tablename__ = "finetune_examples"

    id = Column(Integer, primary_key=True, index=True)
    prompt = Column(Text, nullable=False)
    completion = Column(Text, nullable=False)


class Scenario(Base):
    __tablename__ = "scenarios"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    disc_type = Column(String(1), nullable=False)  # "D", "I", "S", "C"
    personality_template_id = Column(Integer, ForeignKey("personality_templates.id"), nullable=False)
    trait_set_id = Column(Integer, ForeignKey("trait_sets.id"), nullable=False)
    scenario_context_id = Column(Integer, ForeignKey("scenario_contexts.id"), nullable=False)
    ai_system_prompt = Column(Text, nullable=False)
    visibility = Column(String(20), default="personal", nullable=False)  # "personal", "org", "public"
    org_id = Column(Integer, ForeignKey("organizations.id"), nullable=True)  # Only set if visibility="org"
    created_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    personality_template = relationship("PersonalityTemplate", back_populates="scenarios")
    trait_set = relationship("TraitSet", back_populates="scenarios")
    scenario_context = relationship("ScenarioContext", back_populates="scenarios")
    created_by = relationship("User", back_populates="scenarios", foreign_keys=[created_by_user_id])
    organization = relationship("Organization", back_populates="scenarios")
    objectives = relationship("Objective", back_populates="scenario", cascade="all, delete-orphan")
    sessions = relationship("Session", back_populates="scenario")
    training_assignments = relationship("TrainingAssignment", back_populates="scenario", cascade="all, delete-orphan")

    @property
    def transaction_type(self) -> str:
        """Delegate to personality_template so ScenarioListResponse.transaction_type is never None."""
        if self.personality_template:
            return self.personality_template.transaction_type
        return "Unknown"


class Objective(Base):
    __tablename__ = "objectives"

    id = Column(Integer, primary_key=True, index=True)
    scenario_id = Column(Integer, ForeignKey("scenarios.id"), nullable=False)
    label = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    max_points = Column(Integer, default=10, nullable=False)

    # Relationships
    scenario = relationship("Scenario", back_populates="objectives")
    session_objectives = relationship("SessionObjective", back_populates="objective", cascade="all, delete-orphan")


class Session(Base):
    __tablename__ = "sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    scenario_id = Column(Integer, ForeignKey("scenarios.id"), nullable=False)
    status = Column(String(50), default="active", nullable=False)  # "active", "completed", "abandoned"
    score = Column(Integer, default=0, nullable=False)
    appointment_set = Column(Boolean, default=False, nullable=False)
    started_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    ended_at = Column(DateTime, nullable=True)

    # Relationships
    user = relationship("User", back_populates="sessions")
    scenario = relationship("Scenario", back_populates="sessions")
    messages = relationship("Message", back_populates="session", cascade="all, delete-orphan")
    session_objectives = relationship("SessionObjective", back_populates="session", cascade="all, delete-orphan")
    score_events = relationship("SessionScoreEvent", back_populates="session", cascade="all, delete-orphan")


class SessionObjective(Base):
    __tablename__ = "session_objectives"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id"), nullable=False)
    objective_id = Column(Integer, ForeignKey("objectives.id"), nullable=False)
    achieved = Column(Boolean, default=False, nullable=False)
    points_awarded = Column(Integer, default=0, nullable=False)
    notes = Column(Text, nullable=True)
    achieved_at = Column(DateTime, nullable=True)

    # Relationships
    session = relationship("Session", back_populates="session_objectives")
    objective = relationship("Objective", back_populates="session_objectives")


class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id"), nullable=False)
    role = Column(String(50), nullable=False)  # "user", "assistant", "tool_result"
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    session = relationship("Session", back_populates="messages")


class SessionScoreEvent(Base):
    """Audit log for every score mutation — objective completions, bonuses, and DISC alignment."""
    __tablename__ = "session_score_events"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id"), nullable=False)
    event_type = Column(String(50), nullable=False)  # "objective", "bonus", "disc_alignment"
    points = Column(Integer, nullable=False)
    label = Column(String(255), nullable=True)
    reason = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    session = relationship("Session", back_populates="score_events")


# ===== Enterprise Models =====
class Organization(Base):
    """Company account that can manage teams and members."""
    __tablename__ = "organizations"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    max_seats = Column(Integer, nullable=True)  # NULL = unlimited
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    members = relationship("OrgMember", back_populates="organization", cascade="all, delete-orphan")
    teams = relationship("Team", back_populates="organization", cascade="all, delete-orphan")
    scenarios = relationship("Scenario", back_populates="organization", cascade="all, delete-orphan")
    training_assignments = relationship("TrainingAssignment", back_populates="organization", cascade="all, delete-orphan")


class OrgMember(Base):
    """Join table: user membership in an organization with their role."""
    __tablename__ = "org_members"
    __table_args__ = (
        UniqueConstraint('org_id', 'user_id', name='uq_org_user'),
    )

    id = Column(Integer, primary_key=True, index=True)
    org_id = Column(Integer, ForeignKey("organizations.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    org_role = Column(String(50), nullable=False)  # "org_admin", "team_lead", "member"
    is_active = Column(Boolean, default=True, nullable=False)
    joined_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    organization = relationship("Organization", back_populates="members")
    user = relationship("User", back_populates="org_memberships")


class Team(Base):
    """Team within an organization."""
    __tablename__ = "teams"

    id = Column(Integer, primary_key=True, index=True)
    org_id = Column(Integer, ForeignKey("organizations.id"), nullable=False)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    organization = relationship("Organization", back_populates="teams")
    members = relationship("TeamMember", back_populates="team", cascade="all, delete-orphan")
    training_assignments = relationship("TrainingAssignment", back_populates="team", cascade="all, delete-orphan")


class TeamMember(Base):
    """Join table: user membership in a team."""
    __tablename__ = "team_members"
    __table_args__ = (
        UniqueConstraint('team_id', 'user_id', name='uq_team_user'),
    )

    id = Column(Integer, primary_key=True, index=True)
    team_id = Column(Integer, ForeignKey("teams.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    is_team_lead = Column(Boolean, default=False, nullable=False)
    joined_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    team = relationship("Team", back_populates="members")
    user = relationship("User", back_populates="team_memberships")


class TrainingAssignment(Base):
    """Training scenario assigned to a user, team, or entire organization."""
    __tablename__ = "training_assignments"

    id = Column(Integer, primary_key=True, index=True)
    org_id = Column(Integer, ForeignKey("organizations.id"), nullable=False)
    team_id = Column(Integer, ForeignKey("teams.id"), nullable=True)  # If set: assign to whole team
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # If set (team_id null): assign to individual
    scenario_id = Column(Integer, ForeignKey("scenarios.id"), nullable=False)
    due_date = Column(DateTime, nullable=True)
    notes = Column(Text, nullable=True)
    assigned_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    organization = relationship("Organization", back_populates="training_assignments")
    team = relationship("Team", back_populates="training_assignments")
    scenario = relationship("Scenario", back_populates="training_assignments")

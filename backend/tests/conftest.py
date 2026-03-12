"""
Test configuration and shared fixtures for the Convora backend test suite.

REQUIREMENTS:
  - ANTHROPIC_API_KEY must be set in the environment (no mock, no skip).
  - Tests call the real Claude API in test_sessions.py.
"""

import os
import tempfile

# ── Set env vars BEFORE any app module is imported ──────────────────────────
# This ensures app/database.py and app/config.py pick up the test values.
_tmp_db = tempfile.mktemp(suffix="_convora_test.db")
os.environ["DATABASE_URL"] = f"sqlite:///{_tmp_db}"
os.environ.setdefault("JWT_SECRET", "test-jwt-secret-not-for-prod")

_anthropic_key = os.getenv("ANTHROPIC_API_KEY", "")
if not _anthropic_key:
    raise RuntimeError(
        "ANTHROPIC_API_KEY environment variable must be set before running tests.\n"
        "The test suite calls the real Claude API — no mocks, no fallbacks."
    )

# ── Clear settings cache so it re-reads from updated env ────────────────────
from app.config import get_settings as _gs  # noqa: E402
_gs.cache_clear()

# ── Now import everything else ───────────────────────────────────────────────
import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402

from main import app  # noqa: E402  (runs Base.metadata.create_all + seed)
from app.database import Base, get_db  # noqa: E402
from app.models import (  # noqa: E402
    User, PersonalityTemplate, TraitSet, ScenarioContext, Scenario, Objective,
)
from app.utils import hash_password, create_access_token  # noqa: E402
from datetime import timedelta  # noqa: E402

# ── Test engine ──────────────────────────────────────────────────────────────
_test_engine = create_engine(
    f"sqlite:///{_tmp_db}",
    connect_args={"check_same_thread": False},
)
TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_test_engine)


# ── Override FastAPI's get_db with test sessions ─────────────────────────────
def _test_get_db():
    db = TestSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = _test_get_db


# ── Session-scoped fixtures ──────────────────────────────────────────────────

@pytest.fixture(scope="session", autouse=True)
def _init_db():
    """Create all tables in the test database once per session."""
    Base.metadata.create_all(bind=_test_engine)
    yield
    Base.metadata.drop_all(bind=_test_engine)
    if os.path.exists(_tmp_db):
        os.remove(_tmp_db)


@pytest.fixture(scope="session")
def client(_init_db):
    """Starlette TestClient bound to the app with overridden DB."""
    with TestClient(app) as c:
        yield c


@pytest.fixture(scope="session")
def seed_data(_init_db):
    """
    Insert minimal relational seed data once per test session.
    Returns a dict of IDs for downsteam fixtures.
    """
    db = TestSessionLocal()
    try:
        personality = PersonalityTemplate(
            occupation="Financial Analyst",
            transaction_type="Buy",
            surface_motivation="Needs more space for growing family",
            hidden_motivation="Wants to be closer to parents",
            red_flags="Will stall if not given numbers",
        )
        db.add(personality)
        db.flush()

        trait_set = TraitSet(
            trait_set_number=99,
            trait_1="Analytical",
            trait_2="Detail-oriented",
            trait_3="Reserved",
        )
        db.add(trait_set)
        db.flush()

        context = ScenarioContext(name="Test: Open House")
        db.add(context)
        db.flush()

        scenario = Scenario(
            title="Test Scenario — C-type Buyer",
            disc_type="C",
            personality_template_id=personality.id,
            trait_set_id=trait_set.id,
            scenario_context_id=context.id,
            ai_system_prompt=(
                "You are a cautious C-type real-estate client. "
                "Respond naturally but keep answers under 40 words."
            ),
            is_public=True,
        )
        db.add(scenario)
        db.flush()

        objective = Objective(
            scenario_id=scenario.id,
            label="Ask qualifying questions",
            description="ISA asks about budget, timeline, and motivation",
            max_points=10,
        )
        db.add(objective)
        db.commit()

        return {
            "personality_id": personality.id,
            "trait_set_id": trait_set.id,
            "context_id": context.id,
            "scenario_id": scenario.id,
            "objective_id": objective.id,
        }
    finally:
        db.close()


@pytest.fixture(scope="session")
def test_user(_init_db):
    """Register a persistent test user directly in the DB."""
    db = TestSessionLocal()
    try:
        user = User(
            email="tester@convora.test",
            password_hash=hash_password("TestPass123!"),
            name="Test User",
            role="user",
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user
    finally:
        db.close()


@pytest.fixture(scope="session")
def auth_headers(test_user):
    """JWT Authorization header for authenticated requests."""
    token = create_access_token(
        data={"sub": test_user.id},
        expires_delta=timedelta(minutes=60),
    )
    return {"Authorization": f"Bearer {token}"}

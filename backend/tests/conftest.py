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
    """Get the real test user from the database."""
    db = TestSessionLocal()
    try:
        # Use the real test user created in seed data
        user = db.query(User).filter(User.email == "test@example.com").first()
        if not user:
            # Create if it doesn't exist
            user = User(
                email="test@example.com",
                password_hash=hash_password("password123"),
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


@pytest.fixture(scope="session")
def recent_retiree_scenario(_init_db, test_user):
    """
    Fixture for Recent Retiree scenario with 'Did the agent say hello?' objective.
    Used for testing objective completion and scoring.
    """
    db = TestSessionLocal()
    try:
        # Create personality for Recent Retiree
        personality = PersonalityTemplate(
            occupation="Retired Teacher",
            family="Married couple (Patricia and Michael Grant, 67)",
            pets="Cat and dog",
            recreation="Gardening, travel, grandchildren visits",
            transaction_type="Sell & Buy Downsized",
            surface_motivation="Want to downsize to a quality, secure home",
            hidden_motivation="Testing if ISA understands their emotional attachment to the family home",
            timeframe="3-6 months",
            buy_criteria="Quality construction, security, community amenities",
            red_flags="Will stall if pressured; wants data-driven analysis",
        )
        db.add(personality)
        db.flush()

        # Create trait set for C-type (Conscientious)
        trait_set = TraitSet(
            trait_set_number=4,
            trait_1="Analytical",
            trait_2="Quality-focused",
            trait_3="Methodical",
        )
        db.add(trait_set)
        db.flush()

        # Create scenario context
        context = ScenarioContext(name="Listing Appointment")
        db.add(context)
        db.flush()

        # Create Recent Retiree scenario
        scenario = Scenario(
            title="Recent Retiree – Quality Home Downsizer",
            disc_type="C",
            personality_template_id=personality.id,
            trait_set_id=trait_set.id,
            scenario_context_id=context.id,
            ai_system_prompt=(
                "You are a recently retired couple (Patricia and Michael Grant, 67) "
                "seeking a downsized home with quality amenities and security. "
                "Be analytical, quality-focused, and methodical. Request comprehensive documentation."
            ),
            is_public=True,
            created_by_user_id=test_user.id,
        )
        db.add(scenario)
        db.flush()

        # Create objectives for this scenario
        objectives_data = [
            ("Did the agent say hello?", "ISA greets warmly and professionally at the start"),
            ("Did ISA provide market analysis and valuation information?", "ISA shares market data and home valuation"),
            ("Did ISA acknowledge emotional aspect of leaving home?", "ISA recognizes the emotional component"),
            ("Did ISA understand and emphasize quality over speed?", "ISA prioritizes quality and takes time"),
        ]
        
        objectives = []
        for label, description in objectives_data:
            obj = Objective(
                scenario_id=scenario.id,
                label=label,
                description=description,
                max_points=10,
            )
            db.add(obj)
            objectives.append(obj)
        
        db.commit()
        
        return {
            "scenario_id": scenario.id,
            "scenario_title": scenario.title,
            "disc_type": scenario.disc_type,
            "objectives": [(o.id, o.label) for o in objectives],
        }
    finally:
        db.close()

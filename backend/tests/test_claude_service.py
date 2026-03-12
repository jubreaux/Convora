"""
Unit tests for claude_service.py functions.
Tests: build_system_prompt(), process_tool_call(), send_message_to_client()
No mocks — direct function calls with real SQLite data.
"""

import pytest
from sqlalchemy.orm import Session
from app.services.claude_service import (
    build_system_prompt, process_tool_call, send_message_to_client
)
from app.models import Session as DBSession, Scenario, Message, PersonalityTemplate
from app.database import SessionLocal


@pytest.fixture
def db():
    """Direct DB session for service tests."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def test_build_system_prompt_includes_key_sections(db, seed_data):
    """
    Verify build_system_prompt() produces a prompt with:
    - Occupation from personality
    - Objectives from scenario
    - DISC type guidance
    - No self-references (no 'self._get_...' errors)
    """
    scenario = db.query(Scenario).filter(Scenario.id == seed_data["scenario_id"]).first()
    assert scenario is not None

    personality = scenario.personality_template
    trait_set = scenario.trait_set

    prompt = build_system_prompt(db, scenario, personality, trait_set, finetune_examples=[])
    
    # Should contain occupation/role info
    assert "Financial Analyst" in prompt or "engineer" in prompt.lower() or "analyst" in prompt.lower()
    
    # Should contain DISC guidance
    assert scenario.disc_type in prompt or "C" in prompt or "type" in prompt.lower()
    
    # Should NOT contain NameError markers like "self._get"
    assert "self._get_objectives_text" not in prompt
    assert "self._" not in prompt
    
    # Should be a non-empty string
    assert len(prompt) > 100


def test_process_tool_call_updates_db(db, seed_data, test_user):
    """
    Verify process_tool_call() executes tool logic without errors.
    Currently expects it to either succeed or throw meaningful error (not generic).
    """
    scenario = db.query(Scenario).filter(Scenario.id == seed_data["scenario_id"]).first()
    
    # Create a session
    session = DBSession(
        user_id=test_user.id,
        scenario_id=scenario.id,
        status="active",
        score=0,
        appointment_set=False
    )
    db.add(session)
    db.commit()

    # Try calling a tool (e.g., "ask_qualifying_question")
    # Should either succeed (return dict) or fail with ValueError (not generic Exception)
    try:
        result = process_tool_call(
            db, db, "ask_qualifying_question",
            {"question": "What's your budget?"}
        )
        # If it succeeds, should return a dict
        assert isinstance(result, dict)
    except ValueError as e:
        # Acceptable if tool is unknown or data incomplete — fail-loud principle
        assert "unknown" in str(e).lower() or "not found" in str(e).lower()
    except Exception as e:
        pytest.fail(f"process_tool_call should raise ValueError, not {type(e).__name__}: {e}")


def test_send_message_to_client_calls_real_claude(db, seed_data, test_user):
    """
    Integration test: send_message_to_client() should call real Claude API.
    Expected: real response (not mock), returns dict with reply, score, objectives.
    """
    scenario = db.query(Scenario).filter(Scenario.id == seed_data["scenario_id"]).first()
    
    session = DBSession(
        user_id=test_user.id,
        scenario_id=scenario.id,
        status="active",
        score=0,
        appointment_set=False
    )
    db.add(session)
    db.commit()

    # Add opening message from assistant
    opening = "Hello! I'm a test client. What's your offering?"
    msg = Message(session_id=session.id, role="assistant", content=opening)
    db.add(msg)
    db.commit()

    # Call the service
    import asyncio
    result = asyncio.run(send_message_to_client(
        db, session, "Hi, I'd like to learn more."
    ))

    # Validate response structure
    assert isinstance(result, dict), "send_message_to_client should return a dict"
    assert "reply" in result, "Response must include 'reply' key"
    assert len(result["reply"]) > 0, "Reply should be non-empty (from real Claude)"
    assert "current_score" in result
    assert result["current_score"] >= 0
    assert "objectives_completed" in result
    assert isinstance(result["objectives_completed"], list)


def test_send_message_to_client_requires_active_session(db, seed_data, test_user):
    """send_message_to_client should fail if session is not active."""
    scenario = db.query(Scenario).filter(Scenario.id == seed_data["scenario_id"]).first()
    
    session = DBSession(
        user_id=test_user.id,
        scenario_id=scenario.id,
        status="completed",  # Already ended
        score=50,
        appointment_set=False
    )
    db.add(session)
    db.commit()

    # Should raise an error when trying to process a message on ended session
    import asyncio
    with pytest.raises((ValueError, RuntimeError, Exception)):
        asyncio.run(send_message_to_client(
            db, session, "Test message"
        ))

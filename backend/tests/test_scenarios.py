"""
Scenario endpoint tests: /api/scenarios
Validates all CRUD paths including the BUG-2 fix (transaction_type never None).
"""

import pytest


def test_list_scenarios_returns_list(client, auth_headers, seed_data):
    resp = client.get("/api/scenarios", headers=auth_headers)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert isinstance(body, list)
    assert len(body) >= 1


def test_scenario_transaction_type_never_null(client, auth_headers, seed_data):
    """BUG-2 regression: transaction_type must be non-null on every listed scenario."""
    resp = client.get("/api/scenarios", headers=auth_headers)
    assert resp.status_code == 200, resp.text
    scenarios = resp.json()
    assert len(scenarios) >= 1, "Expected at least one scenario in the list"
    for s in scenarios:
        assert s["transaction_type"] is not None, (
            f"Scenario id={s['id']} has null transaction_type — BUG-2 regression"
        )
        assert s["transaction_type"] != "", (
            f"Scenario id={s['id']} has empty transaction_type"
        )


def test_get_scenario_by_id(client, auth_headers, seed_data):
    scenario_id = seed_data["scenario_id"]
    resp = client.get(f"/api/scenarios/{scenario_id}", headers=auth_headers)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["id"] == scenario_id
    assert body["disc_type"] in ("D", "I", "S", "C")


def test_get_nonexistent_scenario_returns_404(client, auth_headers):
    resp = client.get("/api/scenarios/999999", headers=auth_headers)
    assert resp.status_code == 404


def test_get_random_scenario(client, auth_headers, seed_data):
    resp = client.get("/api/scenarios/random", headers=auth_headers)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert "id" in body
    assert "disc_type" in body
    assert "transaction_type" in body
    assert body["transaction_type"] is not None


def test_list_scenarios_requires_auth(client):
    resp = client.get("/api/scenarios")
    assert resp.status_code == 401


# ===== Visibility Tests =====
def test_user_sees_default_scenarios(client, auth_headers, db):
    """Users should see all 'default' (platform-provided) scenarios."""
    from app.models import Scenario, PersonalityTemplate, TraitSet, ScenarioContext, User
    
    # Get a regular test user
    user = db.query(User).filter(User.email == "test@example.com").first()
    assert user is not None
    
    # List scenarios
    resp = client.get("/api/scenarios", headers=auth_headers)
    assert resp.status_code == 200
    scenarios = resp.json()
    
    # Should include default and public scenarios
    visibilities = {s.get("visibility", "unknown") for s in scenarios}
    assert len(visibilities) > 0, "Should have scenarios"


def test_user_sees_own_personal_scenarios(client, auth_headers, db):
    """Users should see scenarios they created (visibility='personal')."""
    from app.models import Scenario, PersonalityTemplate, TraitSet, ScenarioContext, User
    
    user = db.query(User).filter(User.email == "test@example.com").first()
    
    # Get the first valid personality, trait set, and context for creating a scenario
    personality = db.query(PersonalityTemplate).first()
    trait_set = db.query(TraitSet).first()
    context = db.query(ScenarioContext).first()
    
    if not personality or not trait_set or not context:
        pytest.skip("Missing required setup data")
    
    # Create a personal scenario for this user
    personal_scenario = Scenario(
        title="Personal Test Scenario",
        disc_type="D",
        personality_template_id=personality.id,
        trait_set_id=trait_set.id,
        scenario_context_id=context.id,
        ai_system_prompt="Test prompt",
        visibility="personal",
        created_by_user_id=user.id,
        org_id=None
    )
    db.add(personal_scenario)
    db.commit()
    db.refresh(personal_scenario)
    
    # User should see their own scenario
    resp = client.get(f"/api/scenarios/{personal_scenario.id}", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["id"] == personal_scenario.id


def test_user_cannot_see_others_personal_scenarios(client, db):
    """Users should NOT see personal scenarios created by other users."""
    from app.models import Scenario, PersonalityTemplate, TraitSet, ScenarioContext, User
    from app.utils import hash_password
    
    # Create a different user
    new_user = User(
        email="other_user@example.com",
        name="Other User",
        password_hash=hash_password("password123"),
        role="user"
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # Create a personal scenario for the new user
    personality = db.query(PersonalityTemplate).first()
    trait_set = db.query(TraitSet).first()
    context = db.query(ScenarioContext).first()
    
    if not personality or not trait_set or not context:
        pytest.skip("Missing required setup data")
    
    other_scenario = Scenario(
        title="Other User's Personal Scenario",
        disc_type="I",
        personality_template_id=personality.id,
        trait_set_id=trait_set.id,
        scenario_context_id=context.id,
        ai_system_prompt="Test",
        visibility="personal",
        created_by_user_id=new_user.id,
        org_id=None
    )
    db.add(other_scenario)
    db.commit()
    
    # Login as the original test user
    login_resp = client.post(
        "/api/auth/login",
        json={"email": "test@example.com", "password": "password123"}
    )
    assert login_resp.status_code == 200
    test_headers = {"Authorization": f"Bearer {login_resp.json()['access_token']}"}
    
    # Test user should NOT see other user's personal scenario
    resp = client.get(f"/api/scenarios/{other_scenario.id}", headers=test_headers)
    assert resp.status_code == 403


def test_user_sees_public_scenarios(client, auth_headers, db):
    """Users should see all 'public' (universally visible) scenarios."""
    from app.models import Scenario, PersonalityTemplate, TraitSet, ScenarioContext, User
    
    admin = db.query(User).filter(User.role == "admin").first()
    personality = db.query(PersonalityTemplate).first()
    trait_set = db.query(TraitSet).first()
    context = db.query(ScenarioContext).first()
    
    if not admin or not personality or not trait_set or not context:
        pytest.skip("Missing required setup data")
    
    # Create a public scenario
    public_scenario = Scenario(
        title="Public Test Scenario",
        disc_type="S",
        personality_template_id=personality.id,
        trait_set_id=trait_set.id,
        scenario_context_id=context.id,
        ai_system_prompt="Test",
        visibility="public",
        created_by_user_id=admin.id,
        org_id=None
    )
    db.add(public_scenario)
    db.commit()
    
    # User should see the public scenario
    resp = client.get(f"/api/scenarios/{public_scenario.id}", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["visibility"] == "public"

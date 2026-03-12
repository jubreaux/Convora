"""
Session endpoint tests: /api/sessions
Tests the full session lifecycle including real Claude API calls.
No mocks — calls real endpoints.
"""

import pytest


def test_create_session_success(client, auth_headers, seed_data):
    """POST /api/sessions — create a new training session."""
    resp = client.post(
        "/api/sessions",
        headers=auth_headers,
        json={"scenario_id": seed_data["scenario_id"]}
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert "session_id" in body
    assert "message" in body
    assert "scenario_id" in body
    assert body["scenario_id"] == seed_data["scenario_id"]
    return body["session_id"]


def test_send_message_success_and_get_claude_response(client, auth_headers, seed_data):
    """
    POST /api/sessions/{id}/messages — real Claude API call.
    Expected: real response from Claude (not mock), with objectives tracking.
    """
    # Create session
    create_resp = client.post(
        "/api/sessions",
        headers=auth_headers,
        json={"scenario_id": seed_data["scenario_id"]}
    )
    assert create_resp.status_code == 200
    session_id = create_resp.json()["session_id"]

    # Send user message to Claude
    msg_resp = client.post(
        f"/api/sessions/{session_id}/messages",
        headers=auth_headers,
        json={"message": "Hi, I'd like to learn more about homes in the area."}
    )
    assert msg_resp.status_code == 200, msg_resp.text
    body = msg_resp.json()
    
    # Validate response structure (from Claude, not mock)
    assert "reply" in body
    assert len(body["reply"]) > 0, "Claude should return non-empty reply"
    assert isinstance(body["current_score"], int)
    assert body["current_score"] >= 0
    assert isinstance(body["objectives_completed"], list)
    assert isinstance(body["appointment_set"], bool)


def test_send_message_invalid_session_fails(client, auth_headers):
    resp = client.post(
        "/api/sessions/999999/messages",
        headers=auth_headers,
        json={"message": "test"}
    )
    assert resp.status_code == 404


def test_end_session_returns_profile(client, auth_headers, seed_data):
    """
    POST /api/sessions/{id}/end — ends session and reveals full profile.
    Expected: SessionEndResponse with personality, disc_type, traits, objectives.
    """
    # Create session
    create_resp = client.post(
        "/api/sessions",
        headers=auth_headers,
        json={"scenario_id": seed_data["scenario_id"]}
    )
    session_id = create_resp.json()["session_id"]

    # Send a few messages to build up some state
    for _ in range(2):
        client.post(
            f"/api/sessions/{session_id}/messages",
            headers=auth_headers,
            json={"message": "Tell me more."}
        )

    # End session
    end_resp = client.post(
        f"/api/sessions/{session_id}/end",
        headers=auth_headers
    )
    assert end_resp.status_code == 200, end_resp.text
    body = end_resp.json()

    # Validate SessionEndResponse structure
    assert "final_score" in body
    assert isinstance(body["final_score"], int)
    assert body["final_score"] >= 0

    assert "personality" in body
    assert body["personality"]["occupation"] is not None
    assert body["personality"]["transaction_type"] is not None

    assert "trait_set" in body
    assert body["trait_set"]["trait_1"] is not None
    assert body["trait_set"]["trait_2"] is not None
    assert body["trait_set"]["trait_3"] is not None

    assert "disc_type" in body
    assert body["disc_type"] in ("D", "I", "S", "C")

    assert "objectives" in body
    assert isinstance(body["objectives"], list)

    assert "messages" in body
    assert isinstance(body["messages"], list)

    assert "appointment_set" in body
    assert isinstance(body["appointment_set"], bool)


def test_get_user_history_shows_completed_sessions(client, auth_headers, seed_data):
    """
    GET /api/sessions/users/history — lists completed sessions only.
    Requires at least one session to be ended.
    """
    # Create and end a session
    create_resp = client.post(
        "/api/sessions",
        headers=auth_headers,
        json={"scenario_id": seed_data["scenario_id"]}
    )
    session_id = create_resp.json()["session_id"]

    # End it
    client.post(f"/api/sessions/{session_id}/end", headers=auth_headers)

    # Check history
    hist_resp = client.get("/api/sessions/users/history", headers=auth_headers)
    assert hist_resp.status_code == 200, hist_resp.text
    history = hist_resp.json()
    
    assert isinstance(history, list)
    # Should have at least the session we just ended
    assert len(history) >= 1
    
    for session in history:
        assert session["status"] == "completed"
        assert "score" in session
        assert "started_at" in session
        assert "ended_at" in session
        assert session["scenario_title"] is not None


def test_cannot_send_message_to_completed_session(client, auth_headers, seed_data):
    """After session is ended, sending new messages should fail."""
    # Create and end session
    create_resp = client.post(
        "/api/sessions",
        headers=auth_headers,
        json={"scenario_id": seed_data["scenario_id"]}
    )
    session_id = create_resp.json()["session_id"]
    client.post(f"/api/sessions/{session_id}/end", headers=auth_headers)

    # Try to send message to ended session
    msg_resp = client.post(
        f"/api/sessions/{session_id}/messages",
        headers=auth_headers,
        json={"message": "test"}
    )
    assert msg_resp.status_code == 400
    assert "not active" in msg_resp.json()["detail"].lower()

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

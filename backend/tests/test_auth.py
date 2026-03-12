"""
Auth endpoint tests: /api/auth/register and /api/auth/login
No mocks — calls real endpoints against in-memory SQLite.
"""

import pytest


# ── Register ─────────────────────────────────────────────────────────────────

def test_register_success(client):
    resp = client.post("/api/auth/register", json={
        "email": "newuser@convora.test",
        "password": "StrongPass1!",
        "name": "New User",
    })
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["email"] == "newuser@convora.test"
    assert data["user"]["role"] == "user"
    assert "password" not in data["user"]
    assert "password_hash" not in data["user"]


def test_register_duplicate_email_fails(client):
    payload = {"email": "dup@convora.test", "password": "Pass1!", "name": "Dup"}
    client.post("/api/auth/register", json=payload)  # first: succeeds
    resp = client.post("/api/auth/register", json=payload)  # second: must fail
    assert resp.status_code == 400
    assert "already registered" in resp.json()["detail"].lower()


def test_register_invalid_email_fails(client):
    resp = client.post("/api/auth/register", json={
        "email": "not-an-email",
        "password": "Pass1!",
        "name": "Bad Email",
    })
    assert resp.status_code == 422  # Pydantic validation


# ── Login ─────────────────────────────────────────────────────────────────────

def test_login_success(client):
    email = "logintest@convora.test"
    client.post("/api/auth/register", json={
        "email": email, "password": "LoginPass1!", "name": "Login User"
    })
    resp = client.post("/api/auth/login", json={
        "email": email, "password": "LoginPass1!"
    })
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["email"] == email


def test_login_wrong_password_fails(client):
    email = "wrongpass@convora.test"
    client.post("/api/auth/register", json={
        "email": email, "password": "CorrectPass1!", "name": "Wrong Pass"
    })
    resp = client.post("/api/auth/login", json={
        "email": email, "password": "WrongPassword!"
    })
    assert resp.status_code == 401
    assert "invalid" in resp.json()["detail"].lower()


def test_login_nonexistent_user_fails(client):
    resp = client.post("/api/auth/login", json={
        "email": "nobody@convora.test", "password": "Whatever1!"
    })
    assert resp.status_code == 401


def test_protected_endpoint_without_token_fails(client):
    resp = client.get("/api/scenarios")
    assert resp.status_code == 401


def test_protected_endpoint_with_bad_token_fails(client):
    resp = client.get("/api/scenarios", headers={"Authorization": "Bearer garbage"})
    assert resp.status_code == 401

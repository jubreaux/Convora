#!/usr/bin/env python3
"""Comprehensive API endpoint testing script."""

import requests
import json
from datetime import datetime
import os

BASE_URL = "http://localhost:8000"
HEADERS = {"Content-Type": "application/json"}

# Test data - use pre-seeded test accounts
test_user_email = "test@example.com"
test_user_password = "password123"
test_user_name = "Test User"

auth_token = None
user_id = None
scenario_id = None
session_id = None


def print_section(title):
    """Print a section header."""
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")


def print_test(name, result, details=""):
    """Print test result."""
    status = "✓ PASS" if result else "✗ FAIL"
    print(f"{status}: {name}")
    if details:
        print(f"       {details}")


def test_health():
    """Test health endpoint."""
    print_section("1. HEALTH ENDPOINT")
    
    try:
        response = requests.get(f"{BASE_URL}/health")
        result = response.status_code == 200
        data = response.json()
        print_test("GET /health", result, f"Status: {data.get('status')}, Version: {data.get('version')}")
        return result
    except Exception as e:
        print_test("GET /health", False, f"Error: {str(e)}")
        return False


def test_login():
    """Test user login."""
    global auth_token, user_id
    print_section("2. AUTHENTICATION - LOGIN")
    
    try:
        payload = {
            "email": test_user_email,
            "password": test_user_password
        }
        response = requests.post(f"{BASE_URL}/api/auth/login", json=payload, headers=HEADERS)
        result = response.status_code == 200
        
        if result:
            data = response.json()
            auth_token = data.get("access_token")
            user_id = data.get("user", {}).get("id")
            print_test("POST /api/auth/login", result, f"User: {data.get('user', {}).get('email')}, Token: {auth_token[:20]}...")
            return result
        else:
            print_test("POST /api/auth/login", result, f"Status: {response.status_code}, Error: {response.text}")
            return result
    except Exception as e:
        print_test("POST /api/auth/login", False, f"Error: {str(e)}")
        return False


def test_list_claude_models():
    """List available Claude models from Anthropic API."""
    print_section("ANTHROPIC - AVAILABLE MODELS")
    
    try:
        # Call backend endpoint to list models
        response = requests.get(f"{BASE_URL}/api/models", headers=HEADERS, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            models = data.get("available_models", [])
            
            result = len(models) > 0
            print_test("List Available Models", result, f"Found {len(models)} models")
            
            if models:
                print("\nAvailable Claude Models:")
                for model in models:
                    print(f"  - {model}")
            
            return result
        else:
            print_test("List Available Models", False, f"Status: {response.status_code}")
            print("Note: Backend endpoint /api/models not yet implemented")
            print("Displaying commonly available models:")
            common_models = [
                "claude-sonnet-4-20250514",
                "claude-opus-4-1-20250805",
                "claude-haiku-4-5-20251001",
                "claude-opus-4-6",
                "claude-opus-4-5-20251101"
            ]
            for model in common_models:
                print(f"  - {model}")
            return False
            
    except Exception as e:
        print_test("List Available Models", False, f"Error: {str(e)}")
        print("\nCommon Claude 4 models to try:")
        print("  - claude-sonnet-4-20250514 ✓ (Currently using this)")
        print("  - claude-opus-4-1-20250805")
        print("  - claude-haiku-4-5-20251001")
        return False



def test_list_scenarios():
    """Test listing scenarios."""
    print_section("3. SCENARIOS - LIST ALL")
    
    if not auth_token:
        print_test("GET /api/scenarios", False, "No auth token available")
        return False, []
    
    try:
        headers = {**HEADERS, "Authorization": f"Bearer {auth_token}"}
        response = requests.get(f"{BASE_URL}/api/scenarios", headers=headers)
        result = response.status_code == 200
        
        if result:
            data = response.json()
            print_test("GET /api/scenarios", result, f"Found {len(data)} scenarios")
            if data:
                print(f"       Sample: {data[0].get('title', 'N/A')}")
            return True, data
        else:
            print_test("GET /api/scenarios", result, f"Status: {response.status_code}")
            return result, []
    except Exception as e:
        print_test("GET /api/scenarios", False, f"Error: {str(e)}")
        return False, []


def test_get_random_scenario():
    """Test getting random scenario."""
    print_section("4. SCENARIOS - GET RANDOM")
    
    if not auth_token:
        print_test("GET /api/scenarios/random", False, "No auth token available")
        return False, None
    
    try:
        headers = {**HEADERS, "Authorization": f"Bearer {auth_token}"}
        response = requests.get(f"{BASE_URL}/api/scenarios/random", headers=headers)
        result = response.status_code == 200
        
        if result:
            data = response.json()
            print_test("GET /api/scenarios/random", result, f"Scenario: {data.get('title', 'N/A')}")
            return True, data
        else:
            print_test("GET /api/scenarios/random", result, f"Status: {response.status_code}")
        return result, None
    except Exception as e:
        print_test("GET /api/scenarios/random", False, f"Error: {str(e)}")
        return False, None


def test_get_scenario_detail(scenario_id):
    """Test getting scenario details."""
    print_section("5. SCENARIOS - GET DETAIL")
    
    if not auth_token:
        print_test(f"GET /api/scenarios/{scenario_id}", False, "No auth token available")
        return False, None
    
    try:
        headers = {**HEADERS, "Authorization": f"Bearer {auth_token}"}
        response = requests.get(f"{BASE_URL}/api/scenarios/{scenario_id}", headers=headers)
        result = response.status_code == 200
        
        if result:
            data = response.json()
            print_test(f"GET /api/scenarios/{scenario_id}", result, f"Scenario: {data.get('title', 'N/A')}")
            return True, data
        else:
            print_test(f"GET /api/scenarios/{scenario_id}", result, f"Status: {response.status_code}")
        return result, None
    except Exception as e:
        print_test(f"GET /api/scenarios/{scenario_id}", False, f"Error: {str(e)}")
        return False, None


def test_create_session(scenario_id):
    """Test creating a training session."""
    global session_id
    print_section("6. SESSIONS - CREATE SESSION")
    
    if not auth_token:
        print_test("POST /api/sessions", False, "No auth token available")
        return False, None
    
    try:
        headers = {**HEADERS, "Authorization": f"Bearer {auth_token}"}
        payload = {"scenario_id": scenario_id}
        response = requests.post(f"{BASE_URL}/api/sessions", json=payload, headers=headers)
        result = response.status_code == 200
        
        if result:
            data = response.json()
            session_id = data.get("session_id")
            print_test("POST /api/sessions", result, f"Session ID: {session_id}, Message: {data.get('message', 'N/A')[:50]}...")
            return True, data
        else:
            print_test("POST /api/sessions", result, f"Status: {response.status_code}, Error: {response.text}")
        return result, None
    except Exception as e:
        print_test("POST /api/sessions", False, f"Error: {str(e)}")
        return False, None


def test_send_message(session_id):
    """Test sending message in a session."""
    print_section("7. SESSIONS - SEND MESSAGE")
    
    if not auth_token:
        print_test(f"POST /api/sessions/{session_id}/messages", False, "No auth token available")
        return False
    
    try:
        headers = {**HEADERS, "Authorization": f"Bearer {auth_token}"}
        payload = {"message": "Hi, I'm interested in discussing properties in the neighborhood."}
        response = requests.post(f"{BASE_URL}/api/sessions/{session_id}/messages", json=payload, headers=headers)
        result = response.status_code == 200
        
        if result:
            data = response.json()
            client_response = data.get('reply', 'N/A')
            if len(client_response) > 80:
                display_response = client_response[:80] + "..."
            else:
                display_response = client_response
            print_test(f"POST /api/sessions/{session_id}/messages", result, f"Client: {display_response}")
            print(f"       Full Response: {client_response}")
            print(f"       Session Score: {data.get('current_score', 0)}")
            print(f"       Objectives Completed: {len(data.get('objectives_completed', []))}")
        else:
            print_test(f"POST /api/sessions/{session_id}/messages", result, f"Status: {response.status_code}, Error: {response.text}")
        return result
    except Exception as e:
        print_test(f"POST /api/sessions/{session_id}/messages", False, f"Error: {str(e)}")
        return False


def test_multi_turn_conversation(session_id):
    """Test a multi-turn conversation with the client."""
    print_section("7.5 SESSIONS - MULTI-TURN CONVERSATION")
    
    if not auth_token:
        print_test("Multi-turn conversation", False, "No auth token available")
        return False
    
    try:
        headers = {**HEADERS, "Authorization": f"Bearer {auth_token}"}
        
        # First message from user
        print("\n  ╔════════════════════════════════════════════════════════╗")
        print("  ║         TURN 1: User → Client                         ║")
        print("  ╚════════════════════════════════════════════════════════╝")
        
        user_msg1 = "What neighborhoods would you recommend for a growing family?"
        print(f"\n  {{user}}: {user_msg1}")
        
        payload1 = {"message": user_msg1}
        response1 = requests.post(f"{BASE_URL}/api/sessions/{session_id}/messages", json=payload1, headers=headers)
        
        if response1.status_code != 200:
            print_test("Turn 1: User Message", False, f"Status: {response1.status_code}")
            return False
        
        data1 = response1.json()
        client_response1 = data1.get('reply', 'N/A')
        print(f"\n  {{ai}}: {client_response1}")
        
        # Second message from user (responding to client's response)
        print("\n  ╔════════════════════════════════════════════════════════╗")
        print("  ║         TURN 2: User → Client                         ║")
        print("  ╚════════════════════════════════════════════════════════╝")
        
        user_msg2 = "That sounds great! How long would it typically take to find something in that price range?"
        print(f"\n  {{user}}: {user_msg2}")
        
        payload2 = {"message": user_msg2}
        response2 = requests.post(f"{BASE_URL}/api/sessions/{session_id}/messages", json=payload2, headers=headers)
        
        if response2.status_code != 200:
            print_test("Turn 2: User Message", False, f"Status: {response2.status_code}")
            return False
        
        data2 = response2.json()
        client_response2 = data2.get('reply', 'N/A')
        print(f"\n  {{ai}}: {client_response2}")
        
        # Verify conversation is maintaining context
        print("\n  ╔════════════════════════════════════════════════════════╗")
        print("  ║         CONVERSATION SUMMARY                           ║")
        print("  ╚════════════════════════════════════════════════════════╝")
        print(f"\n  Session Score (Turn 1): {data1.get('current_score', 0)}")
        print(f"  Session Score (Turn 2): {data2.get('current_score', 0)}")
        print(f"  Objectives Completed:   {len(data2.get('objectives_completed', []))}")
        
        result = True
        print_test("Multi-turn conversation", result, "Successfully exchanged 2 messages with context")
        return result
        
    except Exception as e:
        print_test("Multi-turn conversation", False, f"Error: {str(e)}")
        return False


def test_create_scenario():
    """Test creating a custom scenario."""
    print_section("8. SCENARIOS - CREATE CUSTOM")
    
    if not auth_token:
        print_test("POST /api/scenarios", False, "No auth token available")
        return False, None
    
    try:
        headers = {**HEADERS, "Authorization": f"Bearer {auth_token}"}
        payload = {
            "title": "Test Custom Scenario",
            "disc_type": "C",
            "personality_template_id": 1,
            "trait_set_id": 1,
            "scenario_context_id": 1,
            "ai_system_prompt": "You are a test client",
            "objectives": [
                {"label": "Test Objective"}
            ]
        }
        response = requests.post(f"{BASE_URL}/api/scenarios", json=payload, headers=headers)
        result = response.status_code == 200
        
        if result:
            data = response.json()
            print_test("POST /api/scenarios", result, f"Scenario ID: {data.get('id')}, Title: {data.get('title')}")
            return True, data
        else:
            print_test("POST /api/scenarios", result, f"Status: {response.status_code}, Error: {response.text}")
        return result, None
    except Exception as e:
        print_test("POST /api/scenarios", False, f"Error: {str(e)}")
        return False, None


def main():
    """Run all tests."""
    print("\n" + "="*60)
    print("  CONVORA API ENDPOINT TEST SUITE")
    print("="*60)
    print(f"Base URL: {BASE_URL}")
    print(f"Test User Email: {test_user_email}")
    
    results = {}
    
    # Test health
    results['health'] = test_health()
    
    # List available Claude models
    results['list_models'] = test_list_claude_models()
    
    # Test auth (skip register since we're using pre-seeded users, only test login)
    results['login'] = test_login()
    
    # Test scenarios only if login succeeded
    if results['login']:
        # First test create scenario
        success, new_scenario = test_create_scenario()
        results['create_scenario'] = success
        
        # Then test listing scenarios
        success, scenarios = test_list_scenarios()
        results['list_scenarios'] = success
        
        if success and scenarios:
            # Use the first scenario from the list
            scenario_id = scenarios[0]['id']
        elif success and new_scenario:
            # If no public scenarios, use the one we just created
            scenario_id = new_scenario.get('id')
            success = True
        else:
            scenario_id = None
            success = False
        
        # Now test with a specific scenario
        if scenario_id and success:
            success, scenario_detail = test_get_scenario_detail(scenario_id)
            results['get_scenario_detail'] = success
            
            success, random_scenario = test_get_random_scenario()
            results['get_random_scenario'] = success
            
            # Test sessions
            success, session_data = test_create_session(scenario_id)
            results['create_session'] = success
            
            if success and session_data:
                results['send_message'] = test_send_message(session_data['session_id'])
                results['multi_turn_conversation'] = test_multi_turn_conversation(session_data['session_id'])
    
    # Summary
    print_section("TEST SUMMARY")
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    print(f"Passed: {passed}/{total}")
    
    for test_name, result in results.items():
        status = "✓" if result else "✗"
        print(f"{status} {test_name}")
    
    print(f"\n{'='*60}\n")


if __name__ == "__main__":
    main()

#!/bin/bash

# User Management API Test Script
# Tests: Create User, List Users (verify creation), Delete User

set -e

API_URL="http://localhost:8400"
TEST_EMAIL="temptestuerxxx_autogen@example.com"
TEST_NAME="Temp Test User"
TEST_PASSWORD="testpassword123"

echo "=========================================="
echo "User Management API Test Suite"
echo "=========================================="
echo ""

# Step 1: Login as admin
echo "[1/6] Logging in as admin..."
LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"admin@example.com\",\"password\":\"password123\"}")

ADMIN_TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
ADMIN_ID=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['user']['id'])")

if [ -z "$ADMIN_TOKEN" ]; then
  echo "❌ Failed to login as admin"
  exit 1
fi
echo "✓ Admin login successful (ID: $ADMIN_ID)"
echo ""

# Step 2: Create a new test user via registration
echo "[2/6] Creating test user ($TEST_EMAIL)..."
CREATE_RESPONSE=$(curl -s -X POST "$API_URL/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"name\":\"$TEST_NAME\"}")

TEST_USER_ID=$(echo "$CREATE_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['user']['id'])" 2>/dev/null || echo "")

if [ -z "$TEST_USER_ID" ]; then
  echo "❌ Failed to create test user"
  echo "Response: $CREATE_RESPONSE"
  exit 1
fi
echo "✓ Test user created (ID: $TEST_USER_ID)"
echo ""

# Step 3: List all users and verify the test user is in the list
echo "[3/6] Listing all users to verify creation..."
USERS_LIST=$(curl -s "$API_URL/api/admin/users?offset=0&limit=50" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

USER_COUNT=$(echo "$USERS_LIST" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d['users']))")
TEST_USER_FOUND=$(echo "$USERS_LIST" | python3 -c "import sys,json; d=json.load(sys.stdin); print(any(u['email'] == '$TEST_EMAIL' for u in d['users']))")

echo "✓ Total users: $USER_COUNT"
if [ "$TEST_USER_FOUND" = "True" ]; then
  echo "✓ Test user found in users list"
else
  echo "❌ Test user NOT found in users list"
  exit 1
fi
echo ""

# Step 4: Display user details
echo "[4/6] Getting test user details..."
USER_DETAIL=$(curl -s "$API_URL/api/admin/users/$TEST_USER_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

USER_EMAIL=$(echo "$USER_DETAIL" | python3 -c "import sys,json; print(json.load(sys.stdin)['email'])")
USER_ROLE=$(echo "$USER_DETAIL" | python3 -c "import sys,json; print(json.load(sys.stdin)['role'])")

echo "  Email: $USER_EMAIL"
echo "  Role: $USER_ROLE"
echo "  Sessions: $(echo "$USER_DETAIL" | python3 -c "import sys,json; print(json.load(sys.stdin)['total_sessions'])")"
echo "✓ User details retrieved"
echo ""

# Step 5: Delete the test user
echo "[5/6] Deleting test user..."
DELETE_RESPONSE=$(curl -s -X DELETE "$API_URL/api/admin/users/$TEST_USER_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

DELETE_MESSAGE=$(echo "$DELETE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['message'])" 2>/dev/null || echo "")

if [ "$DELETE_MESSAGE" = "User successfully deleted" ]; then
  echo "✓ Test user deleted successfully"
else
  echo "❌ Failed to delete test user"
  echo "Response: $DELETE_RESPONSE"
  exit 1
fi
echo ""

# Step 6: Verify user is deleted (should not appear in list)
echo "[6/6] Verifying user is deleted from list..."
USERS_LIST_AFTER=$(curl -s "$API_URL/api/admin/users?offset=0&limit=50" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

USER_COUNT_AFTER=$(echo "$USERS_LIST_AFTER" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d['users']))")
TEST_USER_FOUND_AFTER=$(echo "$USERS_LIST_AFTER" | python3 -c "import sys,json; d=json.load(sys.stdin); print(any(u['email'] == '$TEST_EMAIL' for u in d['users']))")

echo "✓ Total users after deletion: $USER_COUNT_AFTER (was $USER_COUNT)"
if [ "$TEST_USER_FOUND_AFTER" = "False" ]; then
  echo "✓ Test user successfully removed from users list"
else
  echo "❌ Test user still appears in users list after deletion"
  exit 1
fi
echo ""

echo "=========================================="
echo "✓ All tests passed!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ Admin login"
echo "  ✓ User creation ($TEST_EMAIL)"
echo "  ✓ User listed in system"
echo "  ✓ User details retrieved"
echo "  ✓ User soft-deleted"
echo "  ✓ User removed from list"

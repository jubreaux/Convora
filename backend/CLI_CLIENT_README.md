# Convora CLI Chat Client

Quick manual testing tool for the Convora backend without Flutter/web overhead.

## Quick Start

### Prerequisites
- Docker containers running: `docker compose up`
- Backend healthy at `http://localhost:8000`

### Run the Client

```bash
cd backend
python3 Cli_conversation_client.py
```

## How It Works

1. **Welcome Screen** - ASCII art banner
2. **Authentication** - Login with credentials (e.g., `test@example.com` / `password123`)
3. **Scenario Selection** - Pick from available training scenarios
4. **Session Start** - Client sends opening greeting
5. **Interactive Chat** - Type messages back-and-forth with Claude AI

## Commands

| Command | Action |
|---------|--------|
| `any text` | Send message to client |
| `score` | View session stats (ID, scenario, score) |
| `quit` | Exit gracefully |
| `Ctrl+C` | Interrupt session |

## Features

✅ **Clean UI**
- Color-coded sections (green for you, blue for client)
- Success/error/info messages with icons
- Section dividers for readability

✅ **Real-time Chat**
- Back-and-forth conversation with Claude AI
- Displays AI responses in full
- Shows completed objectives + score automatically

✅ **Error Handling**
- Checks backend is running before starting
- Handles network timeouts gracefully
- Descriptive error messages

✅ **Easy Testing**
- No login credentials to remember (pre-seeded)
- Automatic session initialization
- Quick stats lookup with `score` command

## Example Session

```
╔════════════════════════════════════════════════════════════════════╗
║               🎯 CONVORA CLI CHAT CLIENT 🎯                       ║
║               Real Estate Agent Training Simulator                ║
╚════════════════════════════════════════════════════════════════════╝

✓ Backend is healthy

======================================================================
  AUTHENTICATION
======================================================================

Email: test@example.com
Password: password123
✓ Logged in as test@example.com

======================================================================
  SELECT SCENARIO
======================================================================

  1. Test Custom Scenario
     DISC Type: C | Public: False

Select scenario number (1-1): 1
✓ Selected: Test Custom Scenario

======================================================================
  STARTING SESSION
======================================================================

✓ Session created (ID: 42)
ℹ Scenario: Test Custom Scenario

[CLIENT GREETING]

Hi there! I'm interested in discussing properties...

======================================================================
  CONVERSATION
======================================================================

ℹ Type your message and press Enter. Type 'quit' to exit, 'score' to see stats.

──────────────────────────────────────────────────────────────────────

[YOU]: What neighborhoods would you recommend?

[CLIENT]

Well, that's exactly what I'm trying to figure out! As a project manager,
I like to do my research thoroughly before making any decisions...

✓ Session score: 150 points

──────────────────────────────────────────────────────────────────────

[YOU]: score

======================================================================
  SESSION STATS
======================================================================

  Session ID: 42
  Scenario: Test Custom Scenario
  Current Score: 150
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Cannot connect to backend" | Run `docker compose up` in project root |
| "Login failed" | Check credentials (test@example.com / password123) |
| "Request timed out" | Claude API might be slow, try again |
| Colors not showing | Some terminals don't support ANSI codes (Windows cmd) |

## Tips for Testing

- **Test different scenarios** - Select different DISC types to see varied client responses
- **Multi-turn conversations** - Chat with the client across multiple turns to test context awareness
- **Check objectives** - Look for completed objectives in the response to validate training progress
- **Review scores** - Use `score` command to track progress through the scenario

---

**Need backend details?** See `../README.md` for API documentation.

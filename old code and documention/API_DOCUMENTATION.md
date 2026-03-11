# API Documentation - Real Estate Role Play Assistant

## Overview

The Real Estate Role Play Assistant uses a RESTful API built with Node.js and Express. All endpoints are prefixed with `/api`.

**Base URL**: `http://localhost:5000/api`

---

## Authentication

Currently, there is no authentication required. All endpoints are publicly accessible during the MVP phase.

**Future Implementation**: JWT tokens will be required for production.

---

## Endpoints

### 1. Get All Available Scenarios

**Endpoint**: `GET /api/scenarios`

**Purpose**: Retrieve metadata for all available training scenarios

**Request**:
```bash
curl http://localhost:5000/api/scenarios
```

**Response** (200 OK):
```json
[
  {
    "id": "scenario_001",
    "title": "First-Time Home Buyer - Anxious Type",
    "difficulty": "Easy",
    "duration": "10-15 minutes"
  },
  {
    "id": "scenario_002",
    "title": "Investor - Aggressive Buyer",
    "difficulty": "Medium",
    "duration": "15-20 minutes"
  }
]
```

**Response Fields**:
- `id` (string): Unique scenario identifier
- `title` (string): Scenario title
- `difficulty` (string): "Easy", "Medium", or "Hard"
- `duration` (string): Estimated session time

**Error Handling**:
- `500 Internal Server Error`: Server failed to load scenarios

---

### 2. Start a New Training Session

**Endpoint**: `POST /api/sessions`

**Purpose**: Initialize a new training session with a specific scenario

**Request**:
```bash
curl -X POST http://localhost:5000/api/sessions \
  -H "Content-Type: application/json" \
  -d '{"scenarioId": "scenario_001"}'
```

**Request Body**:
```json
{
  "scenarioId": "scenario_001"
}
```

**Response** (200 OK):
```json
{
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "greeting": "Hi, I've been thinking about buying my first home but I'm honestly pretty nervous about the whole process. I'm not sure where to even start.",
  "openingContext": "A potential client has reached out about purchasing their first home. They appear uncertain and need guidance."
}
```

**Response Fields**:
- `sessionId` (string): UUID for the session (use in subsequent requests)
- `greeting` (string): Client's opening message
- `openingContext` (string): Scenario context (without revealing profile)

**Error Handling**:
- `400 Bad Request`: Missing or invalid scenarioId
- `404 Not Found`: Scenario doesn't exist
- `500 Internal Server Error`: Server error during session creation

**Important Notes**:
- Client profile is NOT returned in this response
- Use the sessionId for all subsequent requests
- Session persists in memory until ended

---

### 3. Send Message in Conversation

**Endpoint**: `POST /api/sessions/:sessionId/messages`

**Purpose**: Send ISA message and receive client response

**Request**:
```bash
curl -X POST http://localhost:5000/api/sessions/550e8400-e29b-41d4-a716-446655440000/messages \
  -H "Content-Type: application/json" \
  -d '{
    "message": "I understand your concerns. Let me explain the process step by step.",
    "role": "isa"
  }'
```

**Request Body**:
```json
{
  "message": "I understand your concerns. Let me explain the process step by step.",
  "role": "isa"
}
```

**Request Fields**:
- `message` (string): ISA's message to the client (required)
- `role` (string): Always "isa" for ISA messages

**Response** (200 OK):
```json
{
  "response": "That would be really helpful. Maybe we could talk about this more in detail? When could we set up a time to meet?",
  "appointmentSet": false
}
```

**Response Fields**:
- `response` (string): Client's reply to ISA message
- `appointmentSet` (boolean): True if appointment was successfully set

**Error Handling**:
- `400 Bad Request`: Missing required fields
- `404 Not Found`: Session ID doesn't exist
- `500 Internal Server Error`: Error processing message

**Important Notes**:
- Message is automatically added to conversation history
- Client response is generated based on ISA effectiveness
- If appointmentSet is true, session will auto-end soon
- Maximum conversation length is not enforced (but recommended is ~10 exchanges)

---

### 4. End Session and Get Feedback

**Endpoint**: `POST /api/sessions/:sessionId/end`

**Purpose**: Conclude the session and receive comprehensive feedback

**Request**:
```bash
curl -X POST http://localhost:5000/api/sessions/550e8400-e29b-41d4-a716-446655440000/end
```

**Response** (200 OK):
```json
{
  "clientProfile": {
    "name": "Sarah Martinez",
    "age": 32,
    "budget": "$250,000 - $350,000",
    "timeframe": "3-6 months",
    "discType": "S",
    "discDescription": "Steady, supportive, wants to build long-term relationship",
    "keyTraits": ["Risk-averse", "Prefers personal relationships", ...],
    "painPoints": ["Worried about credit qualification", ...],
    "motivations": ["Build equity instead of paying rent", ...]
  },
  "scenarioDetails": {
    "jobTitle": "Teacher",
    "income": "$55,000/year",
    "creditScore": "650 - Fair",
    ...
  },
  "feedback": {
    "score": 78,
    "strengths": [
      "Excellent questioning technique - asked relevant, probing questions",
      "Demonstrated excellent active listening skills",
      "Successfully set an appointment"
    ],
    "improvements": [
      "Ask more open-ended questions to uncover client needs",
      "Show more active listening by acknowledging and reflecting client concerns"
    ],
    "messagingQuality": {
      "totalMessages": 12,
      "isaMessages": 6,
      "questionRate": "83.3%"
    },
    "discAnalysis": "S"
  },
  "score": 78,
  "messages": [
    {
      "role": "system",
      "content": "A potential client has reached out...",
      "timestamp": "2026-01-12T10:30:00.000Z"
    },
    ...
  ]
}
```

**Response Fields**:

**Client Profile**:
- `name` (string): Client's name
- `age` (number): Client age
- `budget` (string): Budget range
- `timeframe` (string): Timeline for purchase
- `discType` (string): D, I, S, or C
- `discDescription` (string): Description of DISC type
- `keyTraits` (array): Personality characteristics
- `painPoints` (array): Client concerns and challenges
- `motivations` (array): What drives the client

**Scenario Details**:
- `jobTitle` (string): Client's occupation
- `income` (string): Income information
- `creditScore` (string): Credit rating
- Additional scenario-specific fields

**Feedback**:
- `score` (number): 0-100 performance rating
- `strengths` (array): What the ISA did well
- `improvements` (array): Areas for improvement
- `messagingQuality` (object): Conversation metrics
- `discAnalysis` (string): DISC type identified

**Messages Array**:
- Complete conversation history with:
  - `role` (string): "isa", "client", or "system"
  - `content` (string): Message text
  - `timestamp` (ISO string): When message was sent

**Error Handling**:
- `404 Not Found`: Session ID doesn't exist
- `500 Internal Server Error`: Error generating feedback

**Important Notes**:
- Session must have at least one ISA message
- Client profile is revealed after session ends
- Score is calculated based on conversation quality
- All messages are included in response

---

## Performance Scoring

The feedback system evaluates ISAs on a 100-point scale:

| Criterion | Points | Evaluated By |
|-----------|--------|--------------|
| Questioning Technique | 15 | Number and quality of questions |
| Active Listening | 15 | Acknowledgment keywords and reflection |
| Conversation Progression | 10 | Message count and flow |
| Value Communication | 10 | Benefit keywords and relevance |
| Appointment Setting | 20 | Successful scheduling |
| DISC Adaptation | 10 | Communication style matching |
| Overall Professionalism | 10 | Tone and knowledge |
| **Total** | **100** | |

---

## Error Responses

### 400 Bad Request
```json
{
  "error": "Missing required field: scenarioId"
}
```

### 404 Not Found
```json
{
  "error": "Scenario not found"
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal server error message"
}
```

---

## Session Management

### Session Lifecycle

1. **Creation**: `POST /api/sessions` → Session created, stored in memory
2. **Active**: Client and ISA exchange messages via `POST /api/sessions/:id/messages`
3. **Completion**: `POST /api/sessions/:id/end` → Session finalized, feedback generated
4. **Cleanup**: Session removed from memory after 24 hours (future feature)

### Session Timeout

Currently: No session timeout (stored in memory indefinitely)
Future: 24-hour expiration with persistent storage

### Concurrent Sessions

The backend supports unlimited concurrent sessions. Each session is tracked independently.

---

## Rate Limiting

Not currently implemented. 

**Future**: Implement rate limiting to prevent abuse (e.g., 100 requests per minute)

---

## Data Persistence

Current: In-memory storage (volatile)
- Sessions are lost when server restarts
- Suitable for MVP and testing only

Future: Database integration (MongoDB or PostgreSQL)
- Persistent session storage
- User accounts and progress tracking
- Analytics and reporting

---

## Response Times

- GET scenarios: ~50ms
- POST session: ~100ms
- POST message: ~150ms
- POST end: ~200ms

*Times may vary based on system load*

---

## Testing with cURL

### Full Session Example

```bash
# 1. Get available scenarios
curl http://localhost:5000/api/scenarios

# 2. Start a session
RESPONSE=$(curl -X POST http://localhost:5000/api/sessions \
  -H "Content-Type: application/json" \
  -d '{"scenarioId": "scenario_001"}')

SESSION_ID=$(echo $RESPONSE | grep -o '"sessionId":"[^"]*' | cut -d'"' -f4)

# 3. Send a message
curl -X POST http://localhost:5000/api/sessions/$SESSION_ID/messages \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hi, I''d like to help you with your real estate goals. Can you tell me what brings you in today?",
    "role": "isa"
  }'

# 4. End session and get feedback
curl -X POST http://localhost:5000/api/sessions/$SESSION_ID/end
```

---

## CORS Configuration

- **Allowed Origins**: All (*)
- **Allowed Methods**: GET, POST, PUT, DELETE
- **Allowed Headers**: Content-Type
- **Credentials**: Not required

---

## Future API Enhancements

1. **Authentication**: JWT-based user authentication
2. **Profiles**: User account management
3. **Progress**: Session history and score tracking
4. **Analytics**: Advanced performance metrics
5. **WebSocket**: Real-time notifications
6. **Pagination**: Retrieve historical sessions
7. **Filtering**: Query sessions by date, difficulty, score
8. **Webhooks**: Integration with external systems

---

## Integration Examples

### JavaScript/Fetch

```javascript
// Start session
const response = await fetch('http://localhost:5000/api/sessions', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ scenarioId: 'scenario_001' })
});
const session = await response.json();

// Send message
const msgResponse = await fetch(
  `http://localhost:5000/api/sessions/${session.sessionId}/messages`,
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ 
      message: 'Your message here', 
      role: 'isa' 
    })
  }
);
```

### Python

```python
import requests

# Start session
response = requests.post(
    'http://localhost:5000/api/sessions',
    json={'scenarioId': 'scenario_001'}
)
session = response.json()

# Send message
msg_response = requests.post(
    f"http://localhost:5000/api/sessions/{session['sessionId']}/messages",
    json={'message': 'Your message', 'role': 'isa'}
)
```

---

## Support & Troubleshooting

**API Not Responding**: Check if backend is running (`npm start` in backend folder)

**CORS Errors**: Ensure frontend is on correct origin and API is configured

**Session Not Found**: Verify sessionId is correct and session hasn't expired

**Feedback Not Generating**: Ensure at least one message was sent by ISA

---

**Last Updated**: January 12, 2026
**Version**: 1.0.0

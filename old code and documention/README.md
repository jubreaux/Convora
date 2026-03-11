# Real Estate Role Play Assistant

A comprehensive training application designed to help real estate Inside Sales Agents (ISAs) develop and improve their conversation and sales skills through realistic role-play scenarios.

## Features

✨ **Scenario-Based Training**
- 5 diverse real estate scenarios covering different client types and situations
- Each scenario includes hidden client profiles and objectives
- Difficulty levels: Easy, Medium, and Hard

👤 **DISC Profile Integration**
- All client profiles use DISC personality assessment
- Four distinct personality types: Dominant (D), Influencing (I), Steady (S), Conscientious (C)
- Feedback analyzes ISA's ability to adapt to different communication styles

💬 **Interactive Conversation System**
- Real-time messaging interface
- Client responses based on ISA effectiveness
- Dynamic conversation flow that progresses based on dialogue quality

📊 **Comprehensive Performance Scoring**
- Out of 100-point scale
- Detailed feedback on:
  - Questioning technique and depth
  - Active listening demonstrated
  - Needs discovery effectiveness
  - Value proposition communication
  - Appointment setting success
  - DISC style adaptation

📈 **Detailed Analytics**
- Conversation metrics tracking
- Message count and question rate analysis
- Scenario details revealed post-session
- Strength identification and improvement recommendations

## Project Structure

```
app/
├── backend/              # Node.js Express server
│   ├── server.js        # Main server file with API routes
│   ├── package.json     # Backend dependencies
│   └── .gitignore
│
├── frontend/            # React web application
│   ├── src/
│   │   ├── App.js       # Main application component
│   │   ├── App.css      # Styling
│   │   ├── index.js     # Entry point
│   │   └── components/
│   │       ├── ScenarioSelector.js   # Scenario selection UI
│   │       ├── TrainingSession.js    # Conversation interface
│   │       └── FeedbackScreen.js     # Results and feedback display
│   ├── public/
│   │   └── index.html   # HTML template
│   ├── package.json     # Frontend dependencies
│   ├── .env             # Environment variables
│   └── .gitignore
│
└── scenarios/           # JSON scenario files
    ├── scenario_001.json    # First-time buyer (Steady type)
    ├── scenario_002.json    # Investor (Dominant type)
    ├── scenario_003.json    # Relocating family (Influencing type)
    ├── scenario_004.json    # Downsizer (Conscientious type)
    └── scenario_005.json    # Distressed seller (Steady type)
```

## Installation & Setup

### Backend Setup

1. Navigate to the backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```

3. Start the server:
```bash
npm start
```

The server will run on `http://localhost:5000`

### Frontend Setup

1. Navigate to the frontend directory:
```bash
cd frontend
```

2. Install dependencies:
```bash
npm install
```

3. Start the development server:
```bash
npm start
```

The application will open in your browser at `http://localhost:3000`

## Usage

### Starting a Training Session

1. Click on any conversation starter or "Select Scenario"
2. Choose a scenario based on difficulty level
3. Read the opening context provided by the client
4. Engage in natural conversation to:
   - Discover client needs
   - Ask qualifying questions
   - Demonstrate value
   - Set an appointment

### During the Session

- **Client Profile is Hidden**: You won't see the client's background until the session ends
- **Focus on Conversation**: Adapt your approach based on what the client tells you
- **Set an Appointment**: The scenario is "won" when you successfully set an appointment
- **Natural Progression**: The client will respond realistically based on your effectiveness

### After the Session

Once an appointment is set, you'll receive:

1. **Client Profile**: Full details including DISC type, budget, timeline, motivations, pain points
2. **Scenario Details**: What was being tested and evaluated
3. **Performance Score**: 0-100 point rating
4. **Strengths**: What you did well
5. **Improvement Areas**: Where you can focus for next time
6. **Conversation Metrics**: Analysis of your messaging approach

## Scenario Overview

### Scenario 1: First-Time Home Buyer (Easy)
- **DISC Type**: Steady (S)
- **Client**: Sarah Martinez, 32, anxious about process
- **Challenge**: Build trust, provide reassurance, explain process simply
- **Focus**: Active listening, concern acknowledgment, relationship building

### Scenario 2: Aggressive Investor (Medium)
- **DISC Type**: Dominant (D)
- **Client**: James Chen, 45, fast-moving investor
- **Challenge**: Match pace, demonstrate competence, focus on ROI
- **Focus**: Efficiency, results-orientation, networking capability

### Scenario 3: Relocating Family (Medium)
- **DISC Type**: Influencing (I)
- **Client**: Michelle Thompson, 38, enthusiastic, community-focused
- **Challenge**: Match enthusiasm, provide personal connections, understand family needs
- **Focus**: Relationship building, community knowledge, networking

### Scenario 4: Detail-Oriented Downsizer (Hard)
- **DISC Type**: Conscientious (C)
- **Client**: Robert Williams, 62, analytical, data-driven
- **Challenge**: Provide detailed analysis, market data, written documentation
- **Focus**: Analytical approach, accuracy, professionalism, detailed information

### Scenario 5: Distressed Seller (Hard)
- **DISC Type**: Steady (S)
- **Client**: Jennifer Davis, 41, going through divorce
- **Challenge**: Show empathy, provide support, guide through uncertainty
- **Focus**: Emotional intelligence, trust building, supportive approach

## API Endpoints

### Get Available Scenarios
```
GET /api/scenarios
Returns: List of scenarios with metadata (ID, title, difficulty, duration)
```

### Start a New Session
```
POST /api/sessions
Body: { scenarioId: "scenario_001" }
Returns: { sessionId, greeting, openingContext }
```

### Send Message in Conversation
```
POST /api/sessions/:sessionId/messages
Body: { message: "string", role: "isa" }
Returns: { response: "string", appointmentSet: boolean }
```

### End Session and Get Feedback
```
POST /api/sessions/:sessionId/end
Returns: { 
  clientProfile, 
  scenarioDetails, 
  feedback, 
  score, 
  messages 
}
```

## DISC Profile System

The application uses the DISC model to assess both clients and ISA performance:

- **D (Dominant)**: Direct, decisive, results-oriented
- **I (Influencing)**: Enthusiastic, people-focused, relationship-oriented
- **S (Steady)**: Team-oriented, supportive, stable, patient
- **C (Conscientious)**: Detail-oriented, analytical, quality-focused, accurate

Each scenario's client has a specific DISC type, and the feedback evaluates how well the ISA adapted their communication style.

## Scoring Criteria

Performance is evaluated on:

1. **Questioning Technique (15 points)**
   - Quality and relevance of questions asked
   - Mix of open-ended and probing questions
   - Uncover of client needs

2. **Active Listening (15 points)**
   - Acknowledgment of client concerns
   - Reflection of client statements
   - Demonstration of understanding

3. **Conversation Progression (10 points)**
   - Natural flow of dialogue
   - Depth of needs discovery
   - Handling of objections

4. **Value Communication (10 points)**
   - Clear articulation of benefits
   - Alignment with client needs
   - Differentiation from competitors

5. **Appointment Setting (20 points)**
   - Successful scheduling of meeting
   - Clear next steps
   - Client commitment

6. **DISC Adaptation (10 points)**
   - Matching communication style
   - Respect for client preferences
   - Personality-based approach

7. **Overall Professionalism (10 points)**
   - Tone and manner
   - Knowledge demonstration
   - Confidence and credibility

## Technologies Used

### Backend
- **Node.js** - Runtime environment
- **Express.js** - Web framework
- **UUID** - Session ID generation
- **CORS** - Cross-origin resource sharing

### Frontend
- **React** - UI library
- **Axios** - HTTP client
- **CSS3** - Styling with gradients and animations

### Data
- **JSON** - Scenario storage and configuration

## Future Enhancements

- Advanced NLP for more realistic client responses
- Machine learning for conversation analysis
- Multi-language support
- Video recording and playback
- Peer comparison and leaderboards
- Integration with CRM systems
- Mobile app version
- Real-time coach feedback
- Advanced DISC assessment tools
- Scenario customization and creation interface

## Development Notes

### Adding New Scenarios

Create a new JSON file in the `scenarios/` directory following this structure:

```json
{
  "id": "scenario_006",
  "title": "Scenario Title",
  "difficulty": "Easy|Medium|Hard",
  "duration": "10-15 minutes",
  "clientGreeting": "Initial client message",
  "openingContext": "Context without revealing profile",
  "clientResponses": ["Response 1", "Response 2", "Response 3"],
  "clientProfile": {
    "name": "Client Name",
    "age": 35,
    "budget": "$300,000",
    "timeframe": "3 months",
    "discType": "D|I|S|C",
    "discDescription": "Description",
    "keyTraits": ["trait1", "trait2"],
    "painPoints": ["pain1", "pain2"],
    "motivations": ["motivation1", "motivation2"]
  },
  "scenarioDetails": { /* detailed scenario info */ },
  "evaluationCriteria": { /* what's being tested */ }
}
```

### Modifying Feedback Logic

The feedback calculation is in `backend/server.js` in the `calculateFeedback()` function. Adjust weights and criteria as needed.

## License

Proprietary - All rights reserved

## Support

For issues, questions, or feature requests, contact the development team.

---

**Last Updated**: January 12, 2026
**Version**: 1.0.0

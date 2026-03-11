# Copilot Instructions for Real Estate Role Play Assistant

This project is a comprehensive training application for real estate ISAs (Inside Sales Agents) using React, Node.js, and JSON-based scenario data.

## Project Overview

- **Type**: Full-stack web application
- **Frontend**: React 18 with CSS3 styling
- **Backend**: Node.js with Express.js
- **Data**: JSON scenario files with DISC profiles
- **Purpose**: Training real estate agents through role-play conversations

## Key Directories

- `backend/` - Node.js Express API server
- `frontend/` - React web application
- `scenarios/` - JSON files containing training scenarios
- `README.md` - Comprehensive documentation

## Current Features

1. **Scenario Management**: 5 pre-built scenarios with DISC profiles
2. **Training Sessions**: Real-time conversation interface
3. **Performance Scoring**: 0-100 point system with detailed feedback
4. **DISC Analysis**: Client personality assessment and ISA adaptation evaluation
5. **Comprehensive Feedback**: Strengths, improvements, metrics, and scenario analysis

## Installation

```bash
# Backend setup
cd backend
npm install
npm start

# Frontend setup (in new terminal)
cd frontend
npm install
npm start
```

## Development Notes

- **API Base URL**: `http://localhost:5000/api`
- **React Port**: `3000`
- **Express Port**: `5000`
- **Session Management**: In-memory storage (for MVP)
- **DISC Types**: D (Dominant), I (Influencing), S (Steady), C (Conscientious)

## Adding New Scenarios

Create new JSON files in `scenarios/` following the template in scenario_001.json. Each scenario needs:
- Basic metadata (id, title, difficulty, duration)
- Client greeting and opening context
- Client responses array
- Detailed client profile with DISC type
- Scenario-specific details
- Evaluation criteria

## Common Tasks

### View Existing Scenarios
Check `scenarios/` folder for JSON files

### Modify Scoring Weights
Edit `calculateFeedback()` function in `backend/server.js`

### Adjust DISC Analysis
Edit `analyzeDiscAlignment()` function in `backend/server.js`

### Update UI Styling
Edit `frontend/src/App.css`

### Change API Endpoints
Modify both `backend/server.js` and `frontend/src/App.js`

## Architecture Notes

- **Sessions**: Created in-memory on backend (sessionId stored)
- **Feedback Calculation**: Rule-based scoring system analyzing conversation patterns
- **Client Responses**: Currently simplified rule-based system (can be enhanced with NLP)
- **DISC Alignment**: Keyword-based analysis of conversation messages

## Future Enhancements

- Persistent database (MongoDB or PostgreSQL)
- Advanced NLP for realistic client responses
- Machine learning for conversation analysis
- User authentication and progress tracking
- Scenario editor UI
- Real-time WebSocket updates
- Mobile responsive improvements (mostly done)

## File Structure Reference

```
App.js                    → Main app component with state management
ScenarioSelector.js      → Scenario selection UI
TrainingSession.js       → Conversation interface
FeedbackScreen.js        → Results display
server.js               → All API endpoints and logic
scenario_*.json         → Training data for each scenario
App.css                 → All styling
```

## Testing Checklist

- [ ] Backend starts and loads scenarios
- [ ] Frontend connects to API
- [ ] Can select and start a scenario
- [ ] Messages send and receive responses
- [ ] Appointment detection works
- [ ] Feedback displays correctly
- [ ] Navigation between views works
- [ ] DISC feedback appears in results
- [ ] Responsive design on mobile

---

**Last Updated**: January 12, 2026

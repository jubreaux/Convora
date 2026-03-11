const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Load scenarios
const scenariosPath = path.join(__dirname, '../scenarios');
let scenarios = {};

function loadScenarios() {
  const files = fs.readdirSync(scenariosPath).filter(f => f.endsWith('.json'));
  files.forEach(file => {
    const data = JSON.parse(fs.readFileSync(path.join(scenariosPath, file), 'utf8'));
    scenarios[data.id] = data;
  });
}

loadScenarios();

// Store active sessions
const activeSessions = new Map();

// Routes

// Get all scenarios (metadata only)
app.get('/api/scenarios', (req, res) => {
  const scenarioList = Object.values(scenarios).map(s => ({
    id: s.id,
    title: s.title,
    difficulty: s.difficulty,
    duration: s.duration
  }));
  res.json(scenarioList);
});

// Start a new training session
app.post('/api/sessions', (req, res) => {
  const { scenarioId } = req.body;
  
  if (!scenarios[scenarioId]) {
    return res.status(404).json({ error: 'Scenario not found' });
  }

  const sessionId = uuidv4();
  const scenario = scenarios[scenarioId];
  
  const session = {
    id: sessionId,
    scenarioId,
    startTime: new Date(),
    messages: [],
    clientProfile: null, // Hidden until session ends
    scenarioDetails: null, // Hidden until session ends
    status: 'active'
  };

  activeSessions.set(sessionId, session);

  // Return session info without revealing client profile
  res.json({
    sessionId,
    greeting: scenario.clientGreeting,
    openingContext: scenario.openingContext
  });
});

// Send message in conversation
app.post('/api/sessions/:sessionId/messages', (req, res) => {
  const { sessionId } = req.params;
  const { message, role } = req.body;

  const session = activeSessions.get(sessionId);
  if (!session) {
    return res.status(404).json({ error: 'Session not found' });
  }

  // Add message to conversation
  session.messages.push({
    role,
    content: message,
    timestamp: new Date()
  });

  const scenario = scenarios[session.scenarioId];
  
  // Generate AI response based on client behavior
  const aiResponse = generateClientResponse(message, session, scenario);

  session.messages.push({
    role: 'client',
    content: aiResponse,
    timestamp: new Date()
  });

  // Check if appointment was set
  const appointmentSet = checkAppointmentSet(session.messages);

  res.json({
    response: aiResponse,
    appointmentSet
  });
});

// End session and get feedback
app.post('/api/sessions/:sessionId/end', (req, res) => {
  const { sessionId } = req.params;
  const session = activeSessions.get(sessionId);

  if (!session) {
    return res.status(404).json({ error: 'Session not found' });
  }

  const scenario = scenarios[session.scenarioId];
  session.status = 'completed';

  // Calculate performance metrics
  const feedback = calculateFeedback(session, scenario);

  res.json({
    clientProfile: scenario.clientProfile,
    scenarioDetails: scenario.scenarioDetails,
    feedback,
    score: feedback.score,
    messages: session.messages
  });
});

// Helper functions

function generateClientResponse(isaMessage, session, scenario) {
  // Simplified client response based on scenario
  // In production, this would use more sophisticated NLP/AI
  const responses = scenario.clientResponses || [];
  const messageLength = session.messages.length;
  
  // Select response based on conversation flow
  if (messageLength < 4) {
    return responses[0] || "I'm interested in learning more about real estate services.";
  } else if (messageLength < 8) {
    return responses[1] || "Can you tell me about your experience?";
  } else {
    return responses[2] || "That sounds good. When can we meet?";
  }
}

function checkAppointmentSet(messages) {
  const conversationText = messages.map(m => m.content.toLowerCase()).join(' ');
  const appointmentKeywords = ['appointment', 'meet', 'schedule', 'call', 'visit', 'showing', 'time works'];
  
  return appointmentKeywords.some(keyword => conversationText.includes(keyword));
}

function calculateFeedback(session, scenario) {
  const messages = session.messages;
  
  let score = 50; // Base score
  let strengths = [];
  let improvements = [];

  // Analyze conversation quality
  const isaMessages = messages.filter(m => m.role === 'isa');
  
  // Check for questions asked
  const questionCount = isaMessages.filter(m => m.content.includes('?')).length;
  if (questionCount >= 5) {
    score += 15;
    strengths.push('Excellent questioning technique - asked relevant, probing questions');
  } else if (questionCount >= 3) {
    score += 10;
    strengths.push('Good questioning technique');
  } else {
    improvements.push('Ask more open-ended questions to uncover client needs');
  }

  // Check for active listening indicators
  const listeningIndicators = ['understand', 'sounds like', 'so you', 'correct', 'right'];
  const listeningCount = isaMessages.filter(m => 
    listeningIndicators.some(indicator => m.content.toLowerCase().includes(indicator))
  ).length;
  
  if (listeningCount >= 3) {
    score += 15;
    strengths.push('Demonstrated excellent active listening skills');
  } else {
    improvements.push('Show more active listening by acknowledging and reflecting client concerns');
  }

  // Check for needs discovery
  if (messageCount >= 6) {
    score += 10;
    strengths.push('Good conversation progression and needs discovery');
  } else {
    improvements.push('Continue conversation longer to fully discover client needs');
  }

  // Check for value proposition
  const valueKeywords = ['benefit', 'advantage', 'help', 'service', 'solution'];
  const valueCount = isaMessages.filter(m => 
    valueKeywords.some(keyword => m.content.toLowerCase().includes(keyword))
  ).length;
  
  if (valueCount >= 2) {
    score += 10;
    strengths.push('Effectively communicated value proposition');
  } else {
    improvements.push('Better articulate the value and benefits of your services');
  }

  // Check for appointment setting
  const appointmentSet = checkAppointmentSet(messages);
  if (appointmentSet) {
    score += 20;
    strengths.push('Successfully set an appointment');
  } else {
    improvements.push('Focus on closing the conversation with a clear appointment');
  }

  // Check DISC alignment if available
  if (scenario.clientProfile?.discType) {
    const discAnalysis = analyzeDiscAlignment(isaMessages, scenario.clientProfile.discType);
    if (discAnalysis.aligned) {
      score += 10;
      strengths.push(`Good alignment with ${scenario.clientProfile.discType} communication style`);
    } else {
      improvements.push(`Better adapt to ${scenario.clientProfile.discType} communication preferences`);
    }
  }

  // Ensure score is between 0-100
  score = Math.min(100, Math.max(0, score));

  return {
    score,
    strengths,
    improvements,
    messagingQuality: {
      totalMessages: messages.length,
      isaMessages: isaMessages.length,
      questionRate: (questionCount / isaMessages.length * 100).toFixed(1) + '%'
    },
    discAnalysis: scenario.clientProfile?.discType || 'Not analyzed'
  };
}

function analyzeDiscAlignment(messages, discType) {
  // Simplified DISC analysis
  // In production, this would be more sophisticated
  const dominantIndicators = ['quick', 'direct', 'bottom line', 'results'];
  const influencingIndicators = ['enthusiastic', 'relationship', 'fun', 'people'];
  const steadyIndicators = ['team', 'support', 'help', 'loyalty'];
  const conscientiousIndicators = ['quality', 'detail', 'accurate', 'process'];

  const messageText = messages.map(m => m.content.toLowerCase()).join(' ');
  
  let aligned = false;
  switch(discType) {
    case 'D':
      aligned = dominantIndicators.some(i => messageText.includes(i));
      break;
    case 'I':
      aligned = influencingIndicators.some(i => messageText.includes(i));
      break;
    case 'S':
      aligned = steadyIndicators.some(i => messageText.includes(i));
      break;
    case 'C':
      aligned = conscientiousIndicators.some(i => messageText.includes(i));
      break;
  }

  return { aligned };
}

app.listen(PORT, () => {
  console.log(`Real Estate Role Play Assistant backend running on port ${PORT}`);
});

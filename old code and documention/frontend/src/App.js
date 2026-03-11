import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';
import ScenarioSelector from './components/ScenarioSelector';
import TrainingSession from './components/TrainingSession';
import FeedbackScreen from './components/FeedbackScreen';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000/api';

function App() {
  const [appState, setAppState] = useState('menu'); // menu, selecting, training, feedback
  const [scenarios, setScenarios] = useState([]);
  const [selectedScenario, setSelectedScenario] = useState(null);
  const [sessionId, setSessionId] = useState(null);
  const [feedbackData, setFeedbackData] = useState(null);

  useEffect(() => {
    fetchScenarios();
  }, []);

  const fetchScenarios = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/scenarios`);
      setScenarios(response.data);
    } catch (error) {
      console.error('Error fetching scenarios:', error);
    }
  };

  const handleStartTraining = (scenario) => {
    setSelectedScenario(scenario);
    setAppState('training');
  };

  const handleEndSession = (feedback) => {
    setFeedbackData(feedback);
    setAppState('feedback');
  };

  const handleBackToMenu = () => {
    setAppState('menu');
    setSelectedScenario(null);
    setSessionId(null);
    setFeedbackData(null);
  };

  return (
    <div className="app">
      <header className="app-header">
        <h1>🏠 Real Estate Role Play Assistant</h1>
        <p className="subtitle">Training Program for Real Estate ISAs</p>
      </header>

      <main className="app-main">
        {appState === 'menu' && (
          <div className="menu-container">
            <div className="welcome-section">
              <h2>Welcome to Your Training Session</h2>
              <p>
                In this training program, you'll engage in realistic real estate conversations 
                without knowing the client's profile or scenario details in advance. 
              </p>
              <p>
                Focus on asking the right questions, actively listening, and discovering the 
                client's needs through natural conversation. After you successfully set an appointment, 
                you'll receive detailed feedback on your performance.
              </p>
              <div className="conversation-starters">
                <h3>Ready to Begin?</h3>
                <div className="starter-buttons">
                  <button className="starter-btn" onClick={() => setAppState('selecting')}>
                    ✨ Start a new scenario
                  </button>
                  <button className="starter-btn" onClick={() => setAppState('selecting')}>
                    🎯 Begin a training session
                  </button>
                  <button className="starter-btn" onClick={() => setAppState('selecting')}>
                    🚀 I'm ready for the real estate challenge
                  </button>
                  <button className="starter-btn" onClick={() => setAppState('selecting')}>
                    📊 Give me a scenario and let's see my score
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}

        {appState === 'selecting' && (
          <ScenarioSelector 
            scenarios={scenarios} 
            onSelectScenario={handleStartTraining}
            onBackToMenu={handleBackToMenu}
          />
        )}

        {appState === 'training' && selectedScenario && (
          <TrainingSession 
            scenario={selectedScenario} 
            onEndSession={handleEndSession}
            onBackToMenu={handleBackToMenu}
          />
        )}

        {appState === 'feedback' && feedbackData && (
          <FeedbackScreen 
            feedback={feedbackData}
            onBackToMenu={handleBackToMenu}
          />
        )}
      </main>

      <footer className="app-footer">
        <p>© 2026 Real Estate ISA Training Program | Building better agents through realistic practice</p>
      </footer>
    </div>
  );
}

export default App;

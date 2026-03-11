import React, { useState, useEffect } from 'react';
import axios from 'axios';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000/api';

function TrainingSession({ scenario, onEndSession, onBackToMenu }) {
  const [sessionId, setSessionId] = useState(null);
  const [messages, setMessages] = useState([]);
  const [inputValue, setInputValue] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [appointmentSet, setAppointmentSet] = useState(false);
  const [sessionActive, setSessionActive] = useState(true);

  useEffect(() => {
    startSession();
  }, []);

  const startSession = async () => {
    try {
      const response = await axios.post(`${API_BASE_URL}/sessions`, {
        scenarioId: scenario.id
      });
      
      setSessionId(response.data.sessionId);
      setMessages([
        {
          role: 'system',
          content: response.data.openingContext,
          timestamp: new Date()
        },
        {
          role: 'client',
          content: response.data.greeting,
          timestamp: new Date()
        }
      ]);
      setIsLoading(false);
    } catch (error) {
      console.error('Error starting session:', error);
      setIsLoading(false);
    }
  };

  const sendMessage = async () => {
    if (!inputValue.trim() || !sessionId || !sessionActive) return;

    const userMessage = {
      role: 'isa',
      content: inputValue,
      timestamp: new Date()
    };

    setMessages(prev => [...prev, userMessage]);
    setInputValue('');

    try {
      const response = await axios.post(
        `${API_BASE_URL}/sessions/${sessionId}/messages`,
        {
          message: inputValue,
          role: 'isa'
        }
      );

      const clientMessage = {
        role: 'client',
        content: response.data.response,
        timestamp: new Date()
      };

      setMessages(prev => [...prev, clientMessage]);

      if (response.data.appointmentSet) {
        setAppointmentSet(true);
        // Auto-end session after 2 seconds
        setTimeout(() => {
          endSession();
        }, 2000);
      }
    } catch (error) {
      console.error('Error sending message:', error);
    }
  };

  const endSession = async () => {
    if (!sessionId || !sessionActive) return;

    setSessionActive(false);

    try {
      const response = await axios.post(
        `${API_BASE_URL}/sessions/${sessionId}/end`
      );

      onEndSession({
        clientProfile: response.data.clientProfile,
        scenarioDetails: response.data.scenarioDetails,
        feedback: response.data.feedback,
        score: response.data.score,
        messages: response.data.messages
      });
    } catch (error) {
      console.error('Error ending session:', error);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  if (isLoading) {
    return <div className="loading">Initializing scenario...</div>;
  }

  return (
    <div className="training-session">
      <div className="session-header">
        <div>
          <h2>{scenario.title}</h2>
          <p className="session-info">Focus on the conversation. Client profile will be revealed after you set an appointment.</p>
        </div>
        <div className="session-status">
          <span className={`status-badge ${appointmentSet ? 'success' : 'active'}`}>
            {appointmentSet ? '✓ Appointment Set' : '● Active'}
          </span>
        </div>
      </div>

      <div className="conversation-container">
        <div className="messages-list">
          {messages.map((msg, idx) => (
            <div key={idx} className={`message message-${msg.role}`}>
              <div className="message-header">
                <span className="message-role">
                  {msg.role === 'isa' ? '👤 You' : msg.role === 'client' ? '🤝 Client' : '📋 System'}
                </span>
                <span className="message-time">
                  {msg.timestamp?.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </span>
              </div>
              <div className="message-content">{msg.content}</div>
            </div>
          ))}
        </div>

        <div className="input-area">
          <textarea
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="Type your response to the client..."
            disabled={!sessionActive}
            className="message-input"
            rows={3}
          />
          <div className="input-buttons">
            <button 
              onClick={sendMessage} 
              disabled={!inputValue.trim() || !sessionActive}
              className="send-button"
            >
              Send Message
            </button>
            {appointmentSet && (
              <button 
                onClick={endSession} 
                className="end-session-button"
              >
                View Feedback & Score
              </button>
            )}
            {!appointmentSet && (
              <button 
                onClick={endSession} 
                className="end-session-button secondary"
              >
                End Session Early
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default TrainingSession;

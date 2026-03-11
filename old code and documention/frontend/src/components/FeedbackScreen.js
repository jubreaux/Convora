import React from 'react';

function FeedbackScreen({ feedback, onBackToMenu }) {
  return (
    <div className="feedback-screen">
      <button className="back-button" onClick={onBackToMenu}>← New Scenario</button>

      <div className="score-section">
        <h2>Session Complete!</h2>
        <div className="score-display">
          <div className="score-circle">
            <span className="score-number">{feedback.score}</span>
            <span className="score-label">out of 100</span>
          </div>
          <div className="score-interpretation">
            {feedback.score >= 85 && <h3>Excellent Performance! 🌟</h3>}
            {feedback.score >= 70 && feedback.score < 85 && <h3>Good Job! 👍</h3>}
            {feedback.score >= 60 && feedback.score < 70 && <h3>Solid Effort! 💪</h3>}
            {feedback.score < 60 && <h3>Keep Practicing! 📚</h3>}
          </div>
        </div>
      </div>

      <div className="client-info-section">
        <h3>Client Profile (Revealed)</h3>
        {feedback.clientProfile && (
          <div className="client-details">
            <div className="detail-row">
              <span className="label">Name:</span>
              <span className="value">{feedback.clientProfile.name}</span>
            </div>
            <div className="detail-row">
              <span className="label">Age:</span>
              <span className="value">{feedback.clientProfile.age}</span>
            </div>
            <div className="detail-row">
              <span className="label">DISC Type:</span>
              <span className="value disc-type">
                <strong>{feedback.clientProfile.discType}</strong> - {feedback.clientProfile.discDescription}
              </span>
            </div>
            <div className="detail-row">
              <span className="label">Budget:</span>
              <span className="value">{feedback.clientProfile.budget}</span>
            </div>
            <div className="detail-row">
              <span className="label">Timeframe:</span>
              <span className="value">{feedback.clientProfile.timeframe}</span>
            </div>
            <div className="detail-row full-width">
              <span className="label">Key Traits:</span>
              <div className="traits-list">
                {feedback.clientProfile.keyTraits?.map((trait, idx) => (
                  <span key={idx} className="trait-tag">{trait}</span>
                ))}
              </div>
            </div>
            <div className="detail-row full-width">
              <span className="label">Pain Points:</span>
              <ul className="points-list">
                {feedback.clientProfile.painPoints?.map((point, idx) => (
                  <li key={idx}>{point}</li>
                ))}
              </ul>
            </div>
          </div>
        )}
      </div>

      <div className="feedback-section">
        <h3>Your Performance Feedback</h3>
        
        <div className="feedback-subsection strengths">
          <h4>✓ Strengths</h4>
          <ul>
            {feedback.feedback?.strengths?.map((strength, idx) => (
              <li key={idx}>{strength}</li>
            ))}
          </ul>
        </div>

        <div className="feedback-subsection improvements">
          <h4>📈 Areas for Improvement</h4>
          <ul>
            {feedback.feedback?.improvements?.map((improvement, idx) => (
              <li key={idx}>{improvement}</li>
            ))}
          </ul>
        </div>

        {feedback.feedback?.messagingQuality && (
          <div className="metrics-section">
            <h4>Conversation Metrics</h4>
            <div className="metrics-grid">
              <div className="metric">
                <span className="metric-label">Total Messages:</span>
                <span className="metric-value">{feedback.feedback.messagingQuality.totalMessages}</span>
              </div>
              <div className="metric">
                <span className="metric-label">Your Messages:</span>
                <span className="metric-value">{feedback.feedback.messagingQuality.isaMessages}</span>
              </div>
              <div className="metric">
                <span className="metric-label">Questions Asked:</span>
                <span className="metric-value">{feedback.feedback.messagingQuality.questionRate}</span>
              </div>
            </div>
          </div>
        )}
      </div>

      {feedback.scenarioDetails && (
        <div className="scenario-details-section">
          <h3>Scenario Details (Hidden During Session)</h3>
          <p>Here's what we were testing with this scenario:</p>
          <div className="scenario-grid">
            {Object.entries(feedback.scenarioDetails).map(([key, value]) => (
              <div key={key} className="scenario-detail">
                <span className="detail-key">{key.replace(/([A-Z])/g, ' $1')}</span>
                <span className="detail-value">
                  {Array.isArray(value) ? value.join(', ') : String(value)}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="action-buttons">
        <button onClick={onBackToMenu} className="primary-button">
          📋 Try Another Scenario
        </button>
      </div>
    </div>
  );
}

export default FeedbackScreen;

import React from 'react';

function ScenarioSelector({ scenarios, onSelectScenario, onBackToMenu }) {
  return (
    <div className="scenario-selector">
      <button className="back-button" onClick={onBackToMenu}>← Back to Menu</button>
      
      <h2>Select Your Training Scenario</h2>
      <p>Choose a difficulty level to match your experience:</p>

      <div className="scenarios-grid">
        {scenarios.map(scenario => (
          <div key={scenario.id} className="scenario-card">
            <div className="scenario-header">
              <h3>{scenario.title}</h3>
              <span className={`difficulty-badge difficulty-${scenario.difficulty.toLowerCase()}`}>
                {scenario.difficulty}
              </span>
            </div>
            <p className="scenario-duration">⏱️ {scenario.duration}</p>
            <button 
              className="select-scenario-btn"
              onClick={() => onSelectScenario(scenario)}
            >
              Start This Scenario
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

export default ScenarioSelector;

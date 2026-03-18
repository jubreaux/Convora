"""Claude agentic service for conversation handling."""

import json
import logging
from typing import Optional, Dict, Any, List
from anthropic import Anthropic
from sqlalchemy.orm import Session
from app.models import (
    Session as DBSession, Message, SessionObjective, Objective, 
    Scenario, PersonalityTemplate, TraitSet, SessionScoreEvent
)
from app.config import get_settings
from app.tools import CONVERSATION_TOOLS

settings = get_settings()
logger = logging.getLogger(__name__)

# Initialize Claude client with graceful fallback
if settings.ANTHROPIC_API_KEY and settings.ANTHROPIC_API_KEY != "your-anthropic-api-key-here":
    client = Anthropic(api_key=settings.ANTHROPIC_API_KEY)
else:
    client = None  # Will use mock responses


def build_system_prompt(
    db: Session,
    scenario: Scenario,
    personality: PersonalityTemplate,
    trait_set,
    db_session: DBSession
) -> str:
    """
    Build the system prompt for Claude that includes:
    - Scenario context
    - Hidden personality (motivation, red flags)
    - Traits and DISC type
    - Evaluation objectives with real-time status
    - Scoring instructions for dual role (client + evaluator)
    """
    
    traits_str = f"{trait_set.trait_1}, {trait_set.trait_2}, {trait_set.trait_3}"
    
    disc_descriptions = {
        "D": "Dominant - Direct, fast-paced, results-oriented, competitive, commanding",
        "I": "Influential - Outgoing, enthusiastic, optimistic, relationship-focused, persuasive",
        "S": "Steady - Patient, supportive, team-oriented, dependable, good listener",
        "C": "Conscientious - Detail-oriented, analytical, systematic, quality-focused, cautious"
    }
    
    disc_desc = disc_descriptions.get(scenario.disc_type, "Unknown")
    
    # Get objectives and current status
    objectives_list = _get_objectives_text(db, scenario.id)
    objectives_status = _get_objectives_status(db, scenario.id, db_session.id)
    
    # Build the system prompt with client role + evaluator role
    system_prompt = f"""You are playing a DUAL ROLE in this real estate training scenario:
1. ROLE A: You are a realistic real estate client with a hidden profile
2. ROLE B: You are silently evaluating the agent's performance on specific objectives

=== CLIENT PROFILE (VISIBLE TO YOU, NOT THE AGENT) ===
Occupation: {personality.occupation}
Family: {personality.family}
Pets: {personality.pets if personality.pets else 'None'}
Recreation: {personality.recreation}
Transaction Type: {personality.transaction_type}
Buy Criteria: {personality.buy_criteria if personality.buy_criteria else 'N/A'}
Sell Criteria: {personality.sell_criteria if personality.sell_criteria else 'N/A'}

SURFACE MOTIVATION: {personality.surface_motivation}
HIDDEN MOTIVATION: {personality.hidden_motivation}

Timeframe: {personality.timeframe}
Red Flags: {personality.red_flags if personality.red_flags else 'None'}

=== PERSONALITY TRAITS ===
You embody these traits in your responses: {traits_str}

=== COMMUNICATION STYLE ===
DISC Type: {scenario.disc_type} - {disc_desc}
Adapt your communication to reflect this personality type.

=== SCENARIO CONTEXT ===
Scenario: {scenario.scenario_context.name if scenario.scenario_context else 'General'}

=== EVALUATION OBJECTIVES (YOUR ROLE B) ===
You are SILENTLY evaluating the agent against these specific behavioral objectives.
Do NOT tell the agent about this evaluation — just carry out your client role naturally.
Use the provided tools to mark objectives complete as the agent achieves them.

OBJECTIVES TO EVALUATE:{objectives_list}

=== CURRENT OBJECTIVE STATUS ===
Track your progress on objectives. Each message, reassess if new objectives have been completed.
{objectives_status}

=== SCORING INSTRUCTIONS (EVALUATOR ROLE) ===
As you interact with the agent, evaluate their performance:

1. OBJECTIVE COMPLETION: When the agent achieves one of the evaluation objectives above:
   - Use the tool: mark_objective_complete(objective_id=[ID], notes="description of how they achieved it")
   - Replace [ID] with the actual ID number from the objective list above
   - Examples: mark_objective_complete(objective_id=1, notes="Agent opened with warm greeting")
   - Do NOT mention or explain scoring to the agent
   - Each objective is scored only ONCE when first achieved

2. APPOINTMENT SETTING: If you agree to schedule a call/meeting:
   - Use: set_appointment(proposed_time="specific date/time from context")

3. ENDING: If you decide to end the conversation:
   - Use: end_conversation(reason="why you're ending")

CRITICAL RULES FOR SCORING:
- Evaluate each agent message honestly and fairly
- Only mark objectives complete when the agent TRULY achieves them
- Track and reference the status above — don't re-score the same objective twice
- Do NOT use bonus points or DISC alignment tools — scoring comes ONLY from objectives
- Each objective awards its designated max_points value when completed
- Be natural in your client role — don't let evaluation interfere with realistic conversation
- Score happens silently — agent should never know they're being evaluated

=== YOUR ROLE AS CLIENT ===
You are a realistic real estate client in a blind training scenario. The agent (ISA - Inside Sales Agent) 
does not know your profile, motivation, or red flags. Your job is to:

1. Respond authentically as your character would
2. Be conversational and natural
3. Only reveal information that your character would naturally share
4. React to the agent's questions as your personality type would
5. Be helpful but realistic about your constraints

Keep responses concise and natural, as if in a real phone call. Balance your client role with silent evaluation."""
    
    return system_prompt


def _get_objectives_text(db: Session, scenario_id: int) -> str:
    """Get formatted objectives text for the system prompt."""
    objectives = db.query(Objective).filter(Objective.scenario_id == scenario_id).all()
    text = ""
    for obj in objectives:
        text += f"\n- [ID: {obj.id}] \"{obj.label}\" — {obj.description if obj.description else 'N/A'} (max {obj.max_points} pts)"
    return text if text else "\nNo specific objectives defined."


def _get_objectives_status(db: Session, scenario_id: int, session_id: int) -> str:
    """Get formatted objectives status for the system prompt, showing what's been achieved vs outstanding."""
    objectives = db.query(Objective).filter(Objective.scenario_id == scenario_id).all()
    
    text = ""
    for obj in objectives:
        session_obj = db.query(SessionObjective).filter(
            SessionObjective.session_id == session_id,
            SessionObjective.objective_id == obj.id
        ).first()
        
        if session_obj and session_obj.achieved:
            text += f"\n✅ COMPLETED: [ID: {obj.id}] \"{obj.label}\" — +{session_obj.points_awarded} pts"
            if session_obj.notes:
                text += f" (notes: {session_obj.notes})"
        else:
            text += f"\n⬜ OUTSTANDING: [ID: {obj.id}] \"{obj.label}\" — 0/{obj.max_points} pts"
    
    return text if text.strip() else "(No objectives defined for this scenario)"


def process_tool_call(
    db: Session,
    db_session: DBSession,
    tool_name: str,
    tool_input: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Process a tool call from Claude and update the database.
    Returns the result to send back to Claude.
    """
    
    logger.info(f"Tool call: {tool_name} | Input: {tool_input}")
    
    if tool_name == "mark_objective_complete":
        objective_id = tool_input.get("objective_id")
        notes = tool_input.get("notes")
        
        # Check if objective exists and belongs to this session
        objective = db.query(Objective).filter(Objective.id == objective_id).first()
        if not objective:
            return {"error": f"Objective {objective_id} not found"}
        
        # Check if already completed
        session_obj = db.query(SessionObjective).filter(
            SessionObjective.session_id == db_session.id,
            SessionObjective.objective_id == objective_id
        ).first()
        
        points_awarded = 0
        
        if not session_obj:
            # Create new session objective
            session_obj = SessionObjective(
                session_id=db_session.id,
                objective_id=objective_id,
                achieved=True,
                points_awarded=objective.max_points,
                notes=notes
            )
            db.add(session_obj)
            db_session.score += objective.max_points
            points_awarded = objective.max_points
        elif not session_obj.achieved:
            # Mark existing as achieved (only if not already achieved)
            session_obj.achieved = True
            session_obj.points_awarded = objective.max_points
            session_obj.notes = notes
            db_session.score += objective.max_points
            points_awarded = objective.max_points
        else:
            # Already achieved - don't award points again
            db.commit()
            logger.info(f"⚠️ Objective {objective_id} already completed")
            return {
                "status": "already_completed",
                "message": f"Objective {objective_id} was already completed",
                "points_awarded": 0,
                "new_score": db_session.score
            }
        
        db.commit()
        logger.info(f"✅ Objective {objective_id} marked complete | Score: +{points_awarded} → {db_session.score}")
        return {
            "status": "success",
            "points_awarded": points_awarded,
            "new_score": db_session.score
        }
    
    elif tool_name == "add_bonus_points":
        # Bonus points tool should not be used - all scoring comes from objectives
        return {
            "status": "error",
            "message": "Bonus points are not used in this scoring system. All points come from marked objectives."
        }
    
    elif tool_name == "disc_alignment_noted":
        # DISC alignment bonus should not be used - all scoring comes from objectives
        return {
            "status": "error",
            "message": "DISC alignment bonuses are not used in this scoring system. All points come from marked objectives."
        }
    
    elif tool_name == "set_appointment":
        proposed_time = tool_input.get("proposed_time")
        
        db_session.appointment_set = True
        db.commit()
        
        return {
            "status": "success",
            "appointment_set": True,
            "proposed_time": proposed_time,
            "message": "Appointment successfully set! Session will end."
        }
    
    elif tool_name == "end_conversation":
        reason = tool_input.get("reason")
        
        db_session.status = "abandoned"
        db.commit()
        
        return {
            "status": "success",
            "reason": reason,
            "message": "Conversation ended by client."
        }
    
    else:
        return {"error": f"Unknown tool: {tool_name}"}


async def send_message_to_client(
    db: Session,
    db_session: DBSession,
    user_message: str
) -> Dict[str, Any]:
    """
    Send user message to Claude (as client), handle tool calls, and return client's reply.
    
    Returns:
    {
        "reply": str,
        "current_score": int,
        "objectives_completed": list,
        "appointment_set": bool,
        "ended": bool
    }
    """
    
    logger.info(f"📨 User message received (Session: {db_session.id}) | Current score: {db_session.score}")
    
    # Load scenario data
    scenario = db.query(Scenario).filter(Scenario.id == db_session.scenario_id).first()
    personality = db.query(PersonalityTemplate).filter(
        PersonalityTemplate.id == scenario.personality_template_id
    ).first()
    trait_set = db.query(TraitSet).filter(TraitSet.id == scenario.trait_set_id).first()
    
    # Build system prompt with objectives and scoring instructions
    system_prompt = build_system_prompt(db, scenario, personality, trait_set, db_session)
    
    # Get conversation history
    messages = db.query(Message).filter(Message.session_id == db_session.id).all()
    conversation_history = [
        {"role": "user" if m.role == "user" else "assistant", "content": m.content}
        for m in messages
    ]
    
    # Add the new user message
    conversation_history.append({"role": "user", "content": user_message})
    
    # Save user message to DB
    user_msg = Message(session_id=db_session.id, role="user", content=user_message)
    db.add(user_msg)
    db.commit()
    
    # Call Claude with tools
    objectives_completed = []
    assistant_response = ""
    
    try:
        # Check if Claude API key is valid
        if not client or not settings.ANTHROPIC_API_KEY or settings.ANTHROPIC_API_KEY == "your-anthropic-api-key-here":
            # Return mock response for testing
            return generate_mock_response(db, db_session, user_message, personality)
        
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            system=system_prompt,
            tools=CONVERSATION_TOOLS,
            messages=conversation_history
        )
        
        # Process response
        while response.stop_reason == "tool_use":
            # Convert response content blocks to proper dict format
            content_blocks = []
            tool_results = []  # Track tool results to add to history
            
            for block in response.content:
                if hasattr(block, "text") and block.text:
                    assistant_response += block.text
                    content_blocks.append({
                        "type": "text",
                        "text": block.text
                    })
                elif block.type == "tool_use":
                    # Convert tool_use block to dict format
                    content_blocks.append({
                        "type": "tool_use",
                        "id": block.id,
                        "name": block.name,
                        "input": block.input
                    })
                    
                    # Process tool call once
                    tool_result = process_tool_call(db, db_session, block.name, block.input)
                    
                    # Track objectives completed
                    if block.name == "mark_objective_complete" and tool_result.get("status") == "success":
                        objective = db.query(Objective).filter(
                            Objective.id == block.input.get("objective_id")
                        ).first()
                        objectives_completed.append({
                            "objective_id": objective.id,
                            "label": objective.label,
                            "points": objective.max_points,
                            "notes": block.input.get("notes")
                        })
                    
                    # Save tool result for adding to history
                    tool_results.append({
                        "tool_use_id": block.id,
                        "content": json.dumps(tool_result)
                    })
            
            # Add assistant message with properly formatted content blocks
            conversation_history.append({
                "role": "assistant",
                "content": content_blocks
            })
            
            # Add tool results to user message
            if tool_results:
                conversation_history.append({
                    "role": "user",
                    "content": [
                        {
                            "type": "tool_result",
                            "tool_use_id": result["tool_use_id"],
                            "content": result["content"]
                        }
                        for result in tool_results
                    ]
                })
            
            # Continue conversation with tool results
            response = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=1024,
                system=system_prompt,
                tools=CONVERSATION_TOOLS,
                messages=conversation_history
            )
        
        # Extract final text response
        for block in response.content:
            if hasattr(block, "text"):
                assistant_response += block.text
        
        # Save assistant message to DB
        if assistant_response:
            assistant_msg = Message(session_id=db_session.id, role="assistant", content=assistant_response)
            db.add(assistant_msg)
            db.commit()
        
        return {
            "reply": assistant_response,
            "current_score": db_session.score,
            "objectives_completed": objectives_completed,
            "appointment_set": db_session.appointment_set,
            "ended": db_session.status != "active"
        }
    
    except Exception as e:
        # Log full error details
        logger.error(f"Claude API Error: {type(e).__name__}")
        logger.error(f"Error Details: {str(e)}")
        if hasattr(e, 'response') and hasattr(e.response, 'text'):
            logger.error(f"Response Body: {e.response.text}")
        if hasattr(e, '__dict__'):
            logger.error(f"Error Attributes: {e.__dict__}")
        
        # Return detailed error message
        error_msg = str(e)
        if hasattr(e, 'response'):
            try:
                error_msg = json.dumps(e.response.json(), indent=2) if hasattr(e.response, 'json') else str(e)
            except:
                error_msg = str(e)
        
        return {
            "reply": f"Sorry, I encountered an issue: Error code: {str(e)}",
            "current_score": db_session.score,
            "objectives_completed": [],
            "appointment_set": False,
            "ended": False
        }


def generate_mock_response(
    db: Session,
    db_session: DBSession,
    user_message: str,
    personality: PersonalityTemplate
) -> Dict[str, Any]:
    """
    Generate a mock response when Claude API is not available.
    This allows testing without API key.
    """
    # Create a basic response based on personality
    mock_responses = {
        "greeting": f"Thanks for reaching out! I'm interested in discussing real estate opportunities. {personality.occupation if personality.occupation else 'I work in various fields'}.",
        "question": "That's a good question. Can you tell me more about what you specialize in?",
        "proposal": "I appreciate the information. Let me think about this and get back to you.",
        "clarification": "I want to make sure I understand correctly. Are you saying...?",
        "decision": "This sounds interesting. I'd like to schedule a time to discuss this further.",
    }
    
    # Select response based on message length/complexity
    if len(user_message) < 20:
        response = mock_responses["greeting"]
    elif "?" in user_message:
        response = mock_responses["question"]
    elif any(word in user_message.lower() for word in ["appointment", "schedule", "time"]):
        response = mock_responses["decision"]
    elif any(word in user_message.lower() for word in ["clarify", "understand", "mean"]):
        response = mock_responses["clarification"]
    else:
        response = mock_responses["proposal"]
    
    # Save the mock response to DB
    assistant_msg = Message(session_id=db_session.id, role="assistant", content=response)
    db.add(assistant_msg)
    db.commit()
    
    return {
        "reply": response,
        "current_score": db_session.score,
        "objectives_completed": [],
        "appointment_set": False,
        "ended": False
    }

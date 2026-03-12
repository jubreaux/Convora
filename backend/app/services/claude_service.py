"""Claude agentic service for conversation handling."""

import json
from typing import Optional, Dict, Any, List
from anthropic import Anthropic
from sqlalchemy.orm import Session
from app.models import (
    Session as DBSession, Message, SessionObjective, Objective, 
    Scenario, PersonalityTemplate, TraitSet, FinetuneExample
)
from app.config import get_settings
from app.tools import CONVERSATION_TOOLS

settings = get_settings()
client = Anthropic(api_key=settings.ANTHROPIC_API_KEY)


def build_system_prompt(
    db: Session,
    scenario: Scenario,
    personality: PersonalityTemplate,
    trait_set,
    finetune_examples: List[Dict[str, str]]
) -> str:
    """
    Build the system prompt for Claude that includes:
    - Scenario context
    - Hidden personality (motivation, red flags)
    - Traits and DISC type
    - Finetune examples for conversation coaching
    """
    
    traits_str = f"{trait_set.trait_1}, {trait_set.trait_2}, {trait_set.trait_3}"
    
    disc_descriptions = {
        "D": "Dominant - Direct, fast-paced, results-oriented, competitive, commanding",
        "I": "Influential - Outgoing, enthusiastic, optimistic, relationship-focused, persuasive",
        "S": "Steady - Patient, supportive, team-oriented, dependable, good listener",
        "C": "Conscientious - Detail-oriented, analytical, systematic, quality-focused, cautious"
    }
    
    disc_desc = disc_descriptions.get(scenario.disc_type, "Unknown")
    
    # Build finetune context (few-shot examples)
    finetune_context = "## Example conversations (for realistic dialogue):\n"
    for i, example in enumerate(finetune_examples[:10], 1):  # Use first 10 examples
        finetune_context += f"\n{i}. Agent: {example['prompt']}\n   Client: {example['completion']}\n"
    
    system_prompt = _build_system_prompt(db, scenario, personality, trait_set, finetune_list)
    
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
    
    response = client.messages.create(
        model="claude-3-5-sonnet-20241022",
        max_tokens=1024,
        system=system_prompt,
        tools=CONVERSATION_TOOLS,
        messages=conversation_history
    )
    
    # Process response — loop while Claude wants to call tools
    while response.stop_reason == "tool_use":
        for block in response.content:
            if hasattr(block, "text"):
                assistant_response += block.text
            elif block.type == "tool_use":
                tool_result = process_tool_call(db, db_session, block.name, block.input)
                
                if block.name == "mark_objective_complete" and tool_result.get("status") == "success":
                    objective = db.query(Objective).filter(
                        Objective.id == block.input.get("objective_id")
                    ).first()
                    if objective:
                        objectives_completed.append({
                            "objective_id": objective.id,
                            "label": objective.label,
                            "points": objective.max_points,
                            "notes": block.input.get("notes")
                        })
                
                conversation_history.append({
                    "role": "assistant",
                    "content": response.content
                })
                conversation_history.append({
                    "role": "user",
                    "content": [
                        {
                            "type": "tool_result",
                            "tool_use_id": block.id,
                            "content": json.dumps(tool_result)
                        }
                    ]
                })
        
        response = client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=1024,
            system=system_prompt,
            tools=CONVERSATION_TOOLS,
            messages=conversation_history
        )
    
    for block in response.content:
        if hasattr(block, "text"):
            assistant_response += block.text
    
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


class _PLACEHOLDER:
    """Placeholder to keep the old function body below intact for refactor."""
    pass


def _build_system_prompt_ORIG():
    """Original body replaced above."""
    pass


def _build_system_prompt_REAL():
    pass


# ===== REAL build_system_prompt (module-level function, no self) =====
def _build_system_prompt(
    db: Session,
    scenario: Scenario,
    personality: PersonalityTemplate,
    trait_set,
    finetune_examples: List[Dict[str, str]]
) -> str:
    system_prompt = f"""You are playing the role of a real estate client in a blind role-play training scenario.

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
Scenario: {scenario.scenario_context.name}

=== YOUR ROLE ===
You are a realistic real estate client in a blind training scenario. The agent (ISA - Inside Sales Agent) 
does not know your profile, motivation, or red flags. Your job is to:

1. Respond authentically as your character would
2. Be conversational and natural
3. Only reveal information that your character would naturally share
4. React to the agent's questions as your personality type would
5. When you feel an appointment has been genuinely set, use the set_appointment tool
6. Use tools to track the agent's performance on their training objectives

=== TRAINING OBJECTIVES ===
The agent is being scored on these objectives. Award them when genuinely earned:
{self._get_objectives_text(db, scenario.id)}

=== CONVERSATION COACHING ===
{finetune_context}

Use these examples to make realistic, natural real estate conversations. Vary your responses but maintain realism.

=== TOOL USAGE ===
You have tools available to track the agent's performance. Use them when:
- An objective is clearly achieved
- The agent demonstrates exceptional behavior
- An appointment is genuinely set
- The conversation needs to end

Always respond naturally as the client character FIRST, then call tools as needed."""
    return system_prompt


def build_system_prompt(
    db: Session,
    scenario: Scenario,
    personality: PersonalityTemplate,
    trait_set,
    finetune_examples: List[Dict[str, str]]
) -> str:
    return _build_system_prompt(db, scenario, personality, trait_set, finetune_examples)
    
    return system_prompt


def _get_objectives_text(db: Session, scenario_id: int) -> str:
    """Get formatted objectives text for the system prompt."""
    objectives = db.query(Objective).filter(Objective.scenario_id == scenario_id).all()
    text = ""
    for obj in objectives:
        text += f"\n- {obj.label}: {obj.description} (max {obj.max_points} points)"
    return text if text else "\nNo specific objectives defined."


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
        elif not session_obj.achieved:
            # Mark existing as achieved
            session_obj.achieved = True
            session_obj.points_awarded = objective.max_points
            session_obj.notes = notes
            db_session.score += objective.max_points
        
        db.commit()
        return {
            "status": "success",
            "points_awarded": objective.max_points,
            "new_score": db_session.score
        }
    
    elif tool_name == "add_bonus_points":
        amount = tool_input.get("amount", 0)
        reason = tool_input.get("reason", "Bonus awarded")
        
        db_session.score += amount
        db.commit()
        
        return {
            "status": "success",
            "bonus_points": amount,
            "reason": reason,
            "new_score": db_session.score
        }
    
    elif tool_name == "disc_alignment_noted":
        disc_type = tool_input.get("disc_type")
        example = tool_input.get("example")
        
        # Award 5 points for DISC alignment (can be called multiple times)
        points = 5
        db_session.score += points
        db.commit()
        
        return {
            "status": "success",
            "disc_type": disc_type,
            "example": example,
            "points_awarded": points,
            "new_score": db_session.score
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
    
    # Load scenario data
    scenario = db.query(Scenario).filter(Scenario.id == db_session.scenario_id).first()
    personality = db.query(PersonalityTemplate).filter(
        PersonalityTemplate.id == scenario.personality_template_id
    ).first()
    trait_set = db.query(TraitSet).filter(TraitSet.id == scenario.trait_set_id).first()
    
    # Load finetune examples
    finetune_examples = db.query(FinetuneExample).all()
    finetune_list = [{"prompt": ex.prompt, "completion": ex.completion} for ex in finetune_examples]
    
    # Build system prompt
    system_prompt = build_system_prompt(db, scenario, personality, trait_set, finetune_list)
    
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
        response = client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=1024,
            system=system_prompt,
            tools=CONVERSATION_TOOLS,
            messages=conversation_history
        )
        
        # Process response
        while response.stop_reason == "tool_use":
            # Extract text and tool calls from response
            for block in response.content:
                if hasattr(block, "text"):
                    assistant_response += block.text
                elif block.type == "tool_use":
                    # Process tool call
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
                    
                    # Add tool result to conversation
                    conversation_history.append({
                        "role": "assistant",
                        "content": response.content
                    })
                    conversation_history.append({
                        "role": "user",
                        "content": [
                            {
                                "type": "tool_result",
                                "tool_use_id": block.id,
                                "content": json.dumps(tool_result)
                            }
                        ]
                    })
            
            # Continue conversation with tool results
            response = client.messages.create(
                model="claude-3-5-sonnet-20241022",
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
        # Log error and return fallback
        return {
            "reply": f"Sorry, I encountered an issue: {str(e)}",
            "current_score": db_session.score,
            "objectives_completed": [],
            "appointment_set": False,
            "ended": False
        }

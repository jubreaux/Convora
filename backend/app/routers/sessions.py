"""Sessions router - handles training sessions."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime
from app.database import get_db
from app.models import Session as DBSession, Message, Scenario, PersonalityTemplate, TraitSet, SessionObjective, Objective, User, SessionScoreEvent
from app.schemas import (
    SessionCreateRequest, SessionMessageRequest, SessionMessageResponse,
    SessionEndResponse, SessionHistoryResponse, MessageResponse,
    PersonalityTemplateResponse, TraitSetResponse, SessionObjectiveResponse,
    ObjectiveResponse, SessionReviewResponse, SessionScoreEventResponse
)
from app.utils import get_current_user
from app.services.claude_service import send_message_to_client
from app.services.tts_service import synthesize_reply, encode_audio_base64

router = APIRouter(prefix="/api/sessions", tags=["sessions"])


@router.post("", response_model=dict)
async def create_session(
    request: SessionCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a new training session."""
    # Verify scenario exists and is accessible
    scenario = db.query(Scenario).filter(Scenario.id == request.scenario_id).first()
    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")
    
    if not scenario.is_public and scenario.created_by_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Create session
    new_session = DBSession(
        user_id=current_user.id,
        scenario_id=request.scenario_id,
        status="active",
        score=0,
        appointment_set=False
    )
    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    
    # Initialize SessionObjective records for all scenario objectives
    objectives = db.query(Objective).filter(Objective.scenario_id == request.scenario_id).all()
    for objective in objectives:
        session_objective = SessionObjective(
            session_id=new_session.id,
            objective_id=objective.id,
            achieved=False,
            points_awarded=0,
            notes=None
        )
        db.add(session_objective)
    db.commit()
    
    # Initialize with opening context (client's first message)
    personality = db.query(PersonalityTemplate).filter(
        PersonalityTemplate.id == scenario.personality_template_id
    ).first()
    
    opening_message = f"""Hello! I'm {personality.occupation.title() if personality.occupation else 'a client'}, and I'm interested in discussing real estate. What can you tell me about what you do?"""
    
    opening_msg = Message(session_id=new_session.id, role="assistant", content=opening_message)
    db.add(opening_msg)
    db.commit()
    
    return {
        "session_id": new_session.id,
        "message": opening_message,
        "scenario_id": request.scenario_id
    }


@router.post("/{session_id}/messages", response_model=SessionMessageResponse)
async def send_message(
    session_id: int,
    request: SessionMessageRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Send a message in a training session and get client response."""
    # Get session
    session = db.query(DBSession).filter(DBSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Verify user owns this session
    if session.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Check if session is still active
    if session.status != "active":
        raise HTTPException(status_code=400, detail="Session is not active")
    
    # Send message to Claude
    result = await send_message_to_client(db, session, request.message)
    
    # Reload session to capture any updates
    db.refresh(session)
    
    # Get completed objectives
    completed_objectives = db.query(SessionObjective).filter(
        SessionObjective.session_id == session_id,
        SessionObjective.achieved == True
    ).all()
    
    objectives_completed = [
        SessionObjectiveResponse(
            id=so.id,
            objective=ObjectiveResponse.model_validate(so.objective),
            achieved=so.achieved,
            points_awarded=so.points_awarded,
            notes=so.notes,
            achieved_at=so.achieved_at
        )
        for so in completed_objectives
    ]
    
    # Calculate max possible score - query with explicit join to ensure objectives are loaded
    all_session_objectives = db.query(SessionObjective).join(Objective).filter(
        SessionObjective.session_id == session_id
    ).all()
    max_score = sum(so.objective.max_points for so in all_session_objectives) if all_session_objectives else 0
    
    # Synthesize audio if voice mode requested
    audio_base64 = None
    if request.voice:
        scenario = db.query(Scenario).filter(Scenario.id == session.scenario_id).first()
        if not scenario:
            raise HTTPException(status_code=404, detail="Scenario not found for audio synthesis")
        
        try:
            audio_bytes = await synthesize_reply(result["reply"], scenario.disc_type)
            audio_base64 = encode_audio_base64(audio_bytes)
        except RuntimeError as e:
            # Voice mode is optional; fail loudly with meaningful error
            raise HTTPException(status_code=500, detail=f"Audio synthesis failed: {str(e)}")
    
    return SessionMessageResponse(
        reply=result["reply"],
        current_score=session.score,
        max_score=max_score,
        objectives_completed=objectives_completed,
        appointment_set=session.appointment_set,
        audio_base64=audio_base64
    )


@router.get("/users/history", response_model=list[SessionHistoryResponse])
async def get_user_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get current user's session history."""
    sessions = db.query(DBSession).filter(
        DBSession.user_id == current_user.id,
        DBSession.status == "completed"
    ).order_by(DBSession.ended_at.desc()).all()
    
    history = []
    for session in sessions:
        scenario = db.query(Scenario).filter(Scenario.id == session.scenario_id).first()
        history.append(SessionHistoryResponse(
            id=session.id,
            scenario_id=session.scenario_id,
            scenario_title=scenario.title,
            status=session.status,
            score=session.score,
            started_at=session.started_at,
            ended_at=session.ended_at
        ))
    
    return history


@router.get("/users/{user_id}/history", response_model=list[SessionHistoryResponse])
async def get_user_sessions_admin(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get a specific user's session history (admin only)."""
    # Verify admin
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Verify user exists
    target_user = db.query(User).filter(User.id == user_id).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    sessions = db.query(DBSession).filter(
        DBSession.user_id == user_id,
        DBSession.status == "completed"
    ).order_by(DBSession.ended_at.desc()).all()
    
    history = []
    for session in sessions:
        scenario = db.query(Scenario).filter(Scenario.id == session.scenario_id).first()
        history.append(SessionHistoryResponse(
            id=session.id,
            scenario_id=session.scenario_id,
            scenario_title=scenario.title,
            status=session.status,
            score=session.score,
            started_at=session.started_at,
            ended_at=session.ended_at
        ))
    
    return history


@router.get("/{session_id}/review", response_model=SessionReviewResponse)
async def get_session_review(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get a completed session for review: full transcript, scoring breakdown, and personality reveal."""
    session = db.query(DBSession).filter(DBSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    # Allow owner or admin to review
    if session.user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Access denied")

    scenario = db.query(Scenario).filter(Scenario.id == session.scenario_id).first()
    personality = db.query(PersonalityTemplate).filter(
        PersonalityTemplate.id == scenario.personality_template_id
    ).first()
    trait_set = db.query(TraitSet).filter(TraitSet.id == scenario.trait_set_id).first()

    objectives = db.query(SessionObjective).filter(
        SessionObjective.session_id == session_id
    ).all()
    objectives_response = [
        SessionObjectiveResponse(
            id=so.id,
            objective=ObjectiveResponse.model_validate(so.objective),
            achieved=so.achieved,
            points_awarded=so.points_awarded,
            notes=so.notes,
            achieved_at=so.achieved_at
        )
        for so in objectives
    ]

    messages = db.query(Message).filter(
        Message.session_id == session_id
    ).order_by(Message.created_at).all()
    messages_response = [MessageResponse.model_validate(m) for m in messages]

    score_events = db.query(SessionScoreEvent).filter(
        SessionScoreEvent.session_id == session_id
    ).order_by(SessionScoreEvent.created_at).all()
    score_events_response = [SessionScoreEventResponse.model_validate(e) for e in score_events]

    return SessionReviewResponse(
        id=session.id,
        scenario_id=session.scenario_id,
        scenario_title=scenario.title,
        status=session.status,
        final_score=session.score,
        appointment_set=session.appointment_set,
        started_at=session.started_at,
        ended_at=session.ended_at,
        disc_type=scenario.disc_type,
        personality=PersonalityTemplateResponse.model_validate(personality),
        trait_set=TraitSetResponse.model_validate(trait_set),
        objectives=objectives_response,
        messages=messages_response,
        score_events=score_events_response,
    )


@router.get("/{session_id}", response_model=dict)
async def get_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get session details (for reconnection)."""
    session = db.query(DBSession).filter(DBSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    if session.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    messages = db.query(Message).filter(Message.session_id == session_id).all()
    
    return {
        "id": session.id,
        "status": session.status,
        "score": session.score,
        "appointment_set": session.appointment_set,
        "messages": [MessageResponse.model_validate(m) for m in messages]
    }


@router.post("/{session_id}/end", response_model=SessionEndResponse)
async def end_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """End training session and return full feedback."""
    # Get session
    session = db.query(DBSession).filter(DBSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    if session.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Mark session as completed
    session.status = "completed"
    session.ended_at = datetime.utcnow()
    db.commit()
    
    # Load scenario details for full profile reveal
    scenario = db.query(Scenario).filter(Scenario.id == session.scenario_id).first()
    personality = db.query(PersonalityTemplate).filter(
        PersonalityTemplate.id == scenario.personality_template_id
    ).first()
    trait_set = db.query(TraitSet).filter(TraitSet.id == scenario.trait_set_id).first()
    
    # Get achievements
    objectives = db.query(SessionObjective).filter(
        SessionObjective.session_id == session_id
    ).all()
    
    objectives_response = [
        SessionObjectiveResponse(
            id=so.id,
            objective=ObjectiveResponse.model_validate(so.objective),
            achieved=so.achieved,
            points_awarded=so.points_awarded,
            notes=so.notes,
            achieved_at=so.achieved_at
        )
        for so in objectives
    ]
    
    # Get all messages for transcript
    messages = db.query(Message).filter(Message.session_id == session_id).all()
    messages_response = [MessageResponse.model_validate(m) for m in messages]
    
    return SessionEndResponse(
        final_score=session.score,
        personality=PersonalityTemplateResponse.model_validate(personality),
        trait_set=TraitSetResponse.model_validate(trait_set),
        disc_type=scenario.disc_type,
        objectives=objectives_response,
        messages=messages_response,
        appointment_set=session.appointment_set
    )

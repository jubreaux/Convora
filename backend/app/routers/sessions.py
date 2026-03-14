"""Sessions router - handles training sessions."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_
from datetime import datetime
from app.database import get_db
from app.models import Session as DBSession, Message, Scenario, PersonalityTemplate, TraitSet, SessionObjective, Objective, User, SessionScoreEvent, OrgMember
from app.schemas import (
    SessionCreateRequest, SessionMessageRequest, SessionMessageResponse,
    SessionEndResponse, SessionHistoryResponse, MessageResponse,
    PersonalityTemplateResponse, TraitSetResponse, SessionObjectiveResponse,
    ObjectiveResponse, SessionReviewResponse, SessionScoreEventResponse,
    UserStatsResponse, TimelinePoint, DiscTypeStats, ScenarioPerformance
)
from app.utils import get_current_user
from app.services.claude_service import send_message_to_client
from app.services.tts_service import synthesize_reply, encode_audio_base64

router = APIRouter(prefix="/api/sessions", tags=["sessions"])


def _get_user_org_ids(user: User, db: Session) -> list[int]:
    """Get all organization IDs the user is an active member of."""
    org_memberships = db.query(OrgMember).filter(
        OrgMember.user_id == user.id,
        OrgMember.is_active == True
    ).all()
    return [member.org_id for member in org_memberships]


def _can_access_scenario(scenario: Scenario, current_user: User, user_org_ids: list[int]) -> bool:
    """Check if user has access to a scenario based on visibility rules."""
    # Always accessible: default or public scenarios
    if scenario.visibility in ["default", "public"]:
        return True
    
    # Personal scenarios: only if user created it
    if scenario.visibility == "personal":
        return scenario.created_by_user_id == current_user.id
    
    # Org scenarios: only if user is in that org
    if scenario.visibility == "org":
        return scenario.org_id in user_org_ids
    
    return False


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
    
    # Check access using visibility rules
    user_org_ids = _get_user_org_ids(current_user, db)
    if not _can_access_scenario(scenario, current_user, user_org_ids):
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


@router.get("/stats/summary", response_model=UserStatsResponse)
async def get_user_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get comprehensive user statistics."""
    from sqlalchemy import func
    
    # Get all completed sessions for current user
    sessions = db.query(DBSession).filter(
        DBSession.user_id == current_user.id,
        DBSession.status == "completed"
    ).all()
    
    if not sessions:
        # Return empty stats if no sessions
        return UserStatsResponse(
            total_sessions=0,
            avg_score=0.0,
            best_score=0,
            total_objectives_completed=0,
            appointment_rate=0.0,
            timeline=[],
            disc_breakdown={},
            scenario_performance=[]
        )
    
    session_ids = [s.id for s in sessions]
    
    # Aggregate scores
    total_sessions = len(sessions)
    scores = [s.score for s in sessions]
    avg_score = sum(scores) / total_sessions if scores else 0.0
    best_score = max(scores) if scores else 0
    
    # Count completed objectives
    total_objectives_completed = db.query(func.count(SessionObjective.id)).filter(
        SessionObjective.session_id.in_(session_ids),
        SessionObjective.achieved == True
    ).scalar() or 0
    
    # Appointment rate
    with_appointment = db.query(func.count(DBSession.id)).filter(
        DBSession.id.in_(session_ids),
        DBSession.appointment_set == True
    ).scalar() or 0
    appointment_rate = (with_appointment / total_sessions * 100) if total_sessions > 0 else 0.0
    
    # Timeline: last 30 sessions with scenario info
    timeline_sessions = db.query(DBSession, Scenario).join(
        Scenario, DBSession.scenario_id == Scenario.id
    ).filter(
        DBSession.user_id == current_user.id,
        DBSession.status == "completed"
    ).order_by(DBSession.ended_at.asc()).limit(30).all()
    
    timeline = [
        TimelinePoint(
            session_date=s[0].ended_at.isoformat() if s[0].ended_at else s[0].started_at.isoformat(),
            score=s[0].score,
            scenario_title=s[1].title,
            disc_type=s[1].disc_type
        )
        for s in timeline_sessions
    ]
    
    # DISC Breakdown
    disc_breakdown = {}
    for disc_type in ["D", "I", "S", "C"]:
        disc_sessions = db.query(DBSession, Scenario).join(
            Scenario, DBSession.scenario_id == Scenario.id
        ).filter(
            DBSession.user_id == current_user.id,
            DBSession.status == "completed",
            Scenario.disc_type == disc_type
        ).all()
        
        if disc_sessions:
            session_count = len(disc_sessions)
            disc_scores = [s[0].score for s in disc_sessions]
            avg_disc_score = sum(disc_scores) / session_count
            best_disc_score = max(disc_scores)
        else:
            session_count = 0
            avg_disc_score = 0.0
            best_disc_score = 0
        
        disc_breakdown[disc_type] = DiscTypeStats(
            session_count=session_count,
            avg_score=round(avg_disc_score, 2),
            best_score=best_disc_score
        )
    
    # Scenario Performance (across ALL sessions for accuracy)
    all_scenario_sessions = db.query(DBSession, Scenario).join(
        Scenario, DBSession.scenario_id == Scenario.id
    ).filter(
        DBSession.user_id == current_user.id,
        DBSession.status == "completed"
    ).all()
    
    scenario_perf = {}
    for session, scenario in all_scenario_sessions:
        if scenario.title not in scenario_perf:
            scenario_perf[scenario.title] = {"scores": [], "count": 0}
        scenario_perf[scenario.title]["scores"].append(session.score)
        scenario_perf[scenario.title]["count"] += 1
    
    scenario_performance = [
        ScenarioPerformance(
            scenario_title=title,
            session_count=data["count"],
            avg_score=round(sum(data["scores"]) / len(data["scores"]), 2),
            best_score=max(data["scores"])
        )
        for title, data in scenario_perf.items()
    ]
    # Sort by avg_score descending
    scenario_performance.sort(key=lambda x: x.avg_score, reverse=True)
    
    return UserStatsResponse(
        total_sessions=total_sessions,
        avg_score=round(avg_score, 2),
        best_score=best_score,
        total_objectives_completed=total_objectives_completed,
        appointment_rate=round(appointment_rate, 2),
        timeline=timeline,
        disc_breakdown=disc_breakdown,
        scenario_performance=scenario_performance
    )

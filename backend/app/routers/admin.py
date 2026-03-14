from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, case, or_
from app.database import get_db
from app.models import User, Session as SessionModel, Scenario, SessionObjective, PersonalityTemplate, TraitSet, ScenarioContext, Organization, OrgMember
from app.utils import get_current_user, hash_password
from app.schemas import PersonalityTemplateResponse, TraitSetResponse, ScenarioContextResponse, ScenarioDetailResponse, UserResponse, UserUpdate, UserDeleteResponse
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timedelta

router = APIRouter(prefix="/api/admin", tags=["admin"])


# ========== Response Models ==========
class UserStatsResponse(BaseModel):
    id: int
    email: str
    name: str
    role: str
    created_at: datetime
    total_sessions: int
    total_score: int
    avg_session_score: float
    last_session_date: Optional[datetime]
    completed_objectives: int
    org_id: Optional[int] = None
    org_role: Optional[str] = None
    org_name: Optional[str] = None

    class Config:
        from_attributes = True


class UsersListResponse(BaseModel):
    total: int
    users: List[UserStatsResponse]
    offset: int
    limit: int


class DashboardStatsResponse(BaseModel):
    total_users: int
    total_sessions: int
    avg_score: float
    disc_breakdown: dict
    sessions_per_day: List[dict]
    score_distribution: List[dict]
    top_scenarios: List[dict]
    top_users: List[dict]


class ScenarioOwnerInfo(BaseModel):
    """Owner information - either user or organization."""
    id: int
    name: str
    type: str  # "user" or "org"


class AdminScenarioResponse(BaseModel):
    """Scenario info for admin listing with owner details."""
    id: int
    title: str
    disc_type: str
    visibility: str  # "personal", "org", "public"
    owner: ScenarioOwnerInfo  # User or Organization
    created_at: datetime
    created_by_user_id: Optional[int] = None
    org_id: Optional[int] = None

    class Config:
        from_attributes = True


class AdminScenariosListResponse(BaseModel):
    """Paginated list of scenarios for admin."""
    total: int
    scenarios: List[AdminScenarioResponse]
    offset: int
    limit: int


# ========== Helper Functions ==========
def require_admin(current_user: User = Depends(get_current_user)):
    """Verify that the current user is an admin."""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    return current_user


# ========== Endpoints ==========
@router.get("/users", response_model=UsersListResponse)
async def list_users(
    search: str = "",
    offset: int = 0,
    limit: int = 20,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """List all users with pagination and search."""
    
    # Build query - filter out deleted users
    query = db.query(User).filter(User.is_deleted == False)
    
    # Apply search filter
    if search:
        query = query.filter(
            (User.email.ilike(f"%{search}%")) | 
            (User.name.ilike(f"%{search}%"))
        )
    
    # Get total count
    total = query.count()
    
    # Apply pagination
    users = query.offset(offset).limit(limit).all()
    
    # Batch-fetch stats for all users in 2 queries instead of 3×N
    user_ids = [u.id for u in users]

    session_agg = db.query(
        SessionModel.user_id,
        func.count(SessionModel.id).label('total_sessions'),
        func.coalesce(func.sum(SessionModel.score), 0).label('total_score'),
        func.max(SessionModel.started_at).label('last_session_date')
    ).filter(
        SessionModel.user_id.in_(user_ids),
        SessionModel.status == "completed"
    ).group_by(SessionModel.user_id).all()
    session_map = {row.user_id: row for row in session_agg}

    obj_agg = db.query(
        SessionModel.user_id,
        func.count(SessionObjective.id).label('completed_objectives')
    ).join(SessionObjective, SessionObjective.session_id == SessionModel.id).filter(
        SessionModel.user_id.in_(user_ids),
        SessionObjective.achieved == True
    ).group_by(SessionModel.user_id).all()
    obj_map = {row.user_id: row.completed_objectives for row in obj_agg}

    # Batch-fetch org memberships
    org_members = db.query(OrgMember).filter(
        OrgMember.user_id.in_(user_ids),
        OrgMember.is_active == True
    ).all()
    org_member_map = {}
    org_ids_to_fetch = set()
    for org_member in org_members:
        org_member_map[org_member.user_id] = org_member
        org_ids_to_fetch.add(org_member.org_id)
    
    # Batch-fetch organizations
    org_dict = {}
    if org_ids_to_fetch:
        orgs = db.query(Organization).filter(Organization.id.in_(org_ids_to_fetch)).all()
        org_dict = {org.id: org for org in orgs}

    user_stats = []
    for user in users:
        stats = session_map.get(user.id)
        total_sessions = stats.total_sessions if stats else 0
        total_score = int(stats.total_score) if stats else 0
        avg_score = round(total_score / total_sessions, 2) if total_sessions else 0.0
        last_session_date = stats.last_session_date if stats else None
        completed_objectives = obj_map.get(user.id, 0)
        
        # Get org info if user is a member
        org_id = None
        org_role = None
        org_name = None
        org_member = org_member_map.get(user.id)
        if org_member:
            org_id = org_member.org_id
            org_role = org_member.org_role
            org = org_dict.get(org_id)
            if org:
                org_name = org.name

        user_stats.append(UserStatsResponse(
            id=user.id,
            email=user.email,
            name=user.name,
            role=user.role,
            created_at=user.created_at,
            total_sessions=total_sessions,
            total_score=total_score,
            avg_session_score=avg_score,
            last_session_date=last_session_date,
            completed_objectives=completed_objectives,
            org_id=org_id,
            org_role=org_role,
            org_name=org_name
        ))
    
    return UsersListResponse(
        total=total,
        users=user_stats,
        offset=offset,
        limit=limit
    )


@router.get("/users/{user_id}", response_model=UserStatsResponse)
async def get_user_detail(
    user_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Get detailed stats for a specific user."""
    
    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Single aggregated query instead of 3 separate queries
    session_stats = db.query(
        func.count(SessionModel.id),
        func.coalesce(func.sum(SessionModel.score), 0),
        func.max(SessionModel.started_at)
    ).filter(
        SessionModel.user_id == user.id,
        SessionModel.status == "completed"
    ).one()

    total_sessions = session_stats[0] or 0
    total_score = int(session_stats[1]) if session_stats[1] else 0
    last_session_date = session_stats[2]
    avg_score = round(total_score / total_sessions, 2) if total_sessions else 0.0

    completed_objectives = db.query(func.count(SessionObjective.id)).join(
        SessionModel, SessionModel.id == SessionObjective.session_id
    ).filter(
        SessionModel.user_id == user.id,
        SessionObjective.achieved == True
    ).scalar() or 0

    return UserStatsResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        role=user.role,
        created_at=user.created_at,
        total_sessions=total_sessions,
        total_score=total_score,
        avg_session_score=avg_score,
        last_session_date=last_session_date,
        completed_objectives=completed_objectives
    )


@router.get("/stats", response_model=DashboardStatsResponse)
async def get_dashboard_stats(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Get dashboard analytics and statistics."""
    
    # Total users (exclude deleted)
    total_users = db.query(User).filter(User.is_deleted == False).count()
    
    # Total sessions
    total_sessions = db.query(SessionModel).count()
    
    # Average score
    avg_score_result = db.query(func.avg(SessionModel.score)).scalar()
    avg_score = float(avg_score_result) if avg_score_result else 0.0
    
    # DISC breakdown — 1 GROUP BY query instead of 4 separate queries
    disc_rows = db.query(
        Scenario.disc_type,
        func.count(SessionModel.id).label('count')
    ).join(SessionModel, SessionModel.scenario_id == Scenario.id).group_by(Scenario.disc_type).all()
    disc_breakdown = {row.disc_type: row.count for row in disc_rows}
    for t in ['D', 'I', 'S', 'C']:
        disc_breakdown.setdefault(t, 0)
    
    # Sessions per day (last 30 days) — 1 GROUP BY query instead of 30 separate queries
    start_date = datetime.utcnow() - timedelta(days=29)
    day_rows = db.query(
        func.date(SessionModel.started_at).label('day'),
        func.count(SessionModel.id).label('count')
    ).filter(SessionModel.started_at >= start_date).group_by(
        func.date(SessionModel.started_at)
    ).all()
    day_counts = {str(row.day): row.count for row in day_rows}
    sessions_per_day = []
    for i in range(30):
        d = datetime.utcnow() - timedelta(days=29 - i)
        date_str = d.strftime('%Y-%m-%d')
        sessions_per_day.append({"date": date_str, "count": day_counts.get(date_str, 0)})
    
    # Score distribution — 1 query instead of 5 separate range queries
    all_scores = db.query(SessionModel.score).all()
    bins: dict = {"0-20": 0, "20-40": 0, "40-60": 0, "60-80": 0, "80-100": 0}
    for (s,) in all_scores:
        v = s if s is not None else 0
        if v < 20:   bins["0-20"] += 1
        elif v < 40: bins["20-40"] += 1
        elif v < 60: bins["40-60"] += 1
        elif v < 80: bins["60-80"] += 1
        else:        bins["80-100"] += 1
    score_distribution = [{"range": k, "count": v} for k, v in bins.items()]
    
    # Top scenarios by average score
    top_scenarios_query = db.query(
        Scenario.id,
        Scenario.title,
        func.avg(SessionModel.score).label('avg_score'),
        func.count(SessionModel.id).label('session_count')
    ).join(SessionModel).group_by(Scenario.id).order_by(
        func.avg(SessionModel.score).desc()
    ).limit(10).all()
    
    top_scenarios = [
        {
            "id": s[0],
            "title": s[1],
            "avg_score": round(float(s[2]) if s[2] else 0, 2),
            "session_count": s[3]
        }
        for s in top_scenarios_query
    ]
    
    # Top users by score
    top_users_query = db.query(
        User.id,
        User.name,
        User.email,
        func.sum(SessionModel.score).label('total_score')
    ).join(SessionModel).group_by(User.id).order_by(
        func.sum(SessionModel.score).desc()
    ).limit(10).all()
    
    top_users = [
        {
            "id": u[0],
            "name": u[1],
            "email": u[2],
            "total_score": u[3] if u[3] else 0
        }
        for u in top_users_query
    ]
    
    return DashboardStatsResponse(
        total_users=total_users,
        total_sessions=total_sessions,
        avg_score=round(avg_score, 2),
        disc_breakdown=disc_breakdown,
        sessions_per_day=sessions_per_day,
        score_distribution=score_distribution,
        top_scenarios=top_scenarios,
        top_users=top_users
    )


# ========== Dropdown Data Endpoints ==========

@router.get("/personality-templates", response_model=List[PersonalityTemplateResponse])
async def list_personality_templates(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """List all personality templates for scenario edit dropdowns."""
    return db.query(PersonalityTemplate).order_by(PersonalityTemplate.id).all()


@router.get("/trait-sets", response_model=List[TraitSetResponse])
async def list_trait_sets(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """List all trait sets for scenario edit dropdowns."""
    return db.query(TraitSet).order_by(TraitSet.trait_set_number).all()


@router.get("/scenario-contexts", response_model=List[ScenarioContextResponse])
async def list_scenario_contexts(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """List all scenario contexts for scenario edit dropdowns."""
    return db.query(ScenarioContext).order_by(ScenarioContext.name).all()


# ========== User Management Endpoints ==========

@router.patch("/users/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: int,
    user_data: UserUpdate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Update user details (admin only). Cannot demote self."""
    
    # Prevent self-demotion
    if user_id == current_user.id and user_data.role and user_data.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot demote yourself"
        )
    
    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Check email uniqueness if changing email
    if user_data.email and user_data.email != user.email:
        existing_user = db.query(User).filter(
            User.email == user_data.email,
            User.is_deleted == False
        ).first()
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already in use"
            )
    
    # Update fields
    if user_data.name is not None:
        user.name = user_data.name
    if user_data.email is not None:
        user.email = user_data.email
    if user_data.password is not None:
        user.password_hash = hash_password(user_data.password)
    if user_data.role is not None:
        user.role = user_data.role
    
    db.commit()
    db.refresh(user)
    return user


@router.delete("/users/{user_id}", response_model=UserDeleteResponse)
async def delete_user(
    user_id: int,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Soft delete a user (mark as deleted, preserve data). Cannot delete self."""
    
    # Prevent self-deletion
    if user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot delete yourself"
        )
    
    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Soft delete
    user.is_deleted = True
    db.commit()
    
    return UserDeleteResponse(
        message="User successfully deleted",
        user_id=user_id,
        deleted_at=datetime.utcnow()
    )


# ========== Admin Scenarios Endpoints ==========
@router.get("/scenarios", response_model=AdminScenariosListResponse)
async def list_admin_scenarios(
    search: str = Query("", description="Search by title or prompt"),
    visibility: Optional[str] = Query(None, description="Filter by visibility: personal, org, or public"),
    offset: int = Query(0, ge=0, description="Pagination offset"),
    limit: int = Query(50, ge=1, le=500, description="Pagination limit"),
    sort_by: str = Query("created_at", description="Sort by: title, created_at, visibility, disc_type"),
    sort_order: str = Query("desc", regex="^(asc|desc)$", description="Sort order: asc or desc"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    """
    List all scenarios with admin controls.
    - Search by title or AI system prompt
    - Filter by visibility (personal, org, public)
    - Sortable columns
    - Pagination
    """
    
    # Start query
    query = db.query(Scenario)
    
    # Apply filters
    if search:
        search_term = f"%{search}%"
        query = query.filter(
            or_(
                Scenario.title.ilike(search_term),
                Scenario.ai_system_prompt.ilike(search_term)
            )
        )
    
    if visibility:
        if visibility not in ["personal", "org", "public"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid visibility. Must be one of: personal, org, public"
            )
        query = query.filter(Scenario.visibility == visibility)
    
    # Get total count
    total = query.count()
    
    # Apply sorting
    sort_column_map = {
        "title": Scenario.title,
        "created_at": Scenario.created_at,
        "visibility": Scenario.visibility,
        "disc_type": Scenario.disc_type,
    }
    
    sort_column = sort_column_map.get(sort_by, Scenario.created_at)
    if sort_order == "asc":
        query = query.order_by(sort_column.asc())
    else:
        query = query.order_by(sort_column.desc())
    
    # Apply pagination
    scenarios = query.offset(offset).limit(limit).all()
    
    # Build response with owner info
    result_scenarios = []
    for scenario in scenarios:
        owner = None
        
        if scenario.org_id:
            org = db.query(Organization).filter(Organization.id == scenario.org_id).first()
            if org:
                owner = ScenarioOwnerInfo(id=org.id, name=org.name, type="org")
        elif scenario.created_by_user_id:
            user = db.query(User).filter(User.id == scenario.created_by_user_id).first()
            if user:
                owner = ScenarioOwnerInfo(id=user.id, name=user.name, type="user")
        
        if not owner:
            owner = ScenarioOwnerInfo(id=0, name="System", type="system")
        
        result_scenarios.append(AdminScenarioResponse(
            id=scenario.id,
            title=scenario.title,
            disc_type=scenario.disc_type,
            visibility=scenario.visibility,
            owner=owner,
            created_at=scenario.created_at,
            created_by_user_id=scenario.created_by_user_id,
            org_id=scenario.org_id,
        ))
    
    return AdminScenariosListResponse(
        total=total,
        scenarios=result_scenarios,
        offset=offset,
        limit=limit
    )


@router.put("/scenarios/{scenario_id}/visibility")
async def update_scenario_visibility(
    scenario_id: int,
    visibility: str = Query(..., regex="^(personal|org|default|public)$", description="New visibility level"),
    org_id: Optional[int] = Query(None, description="Organization ID (required if visibility=org)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    """Update scenario visibility level (admin only)."""
    scenario = db.query(Scenario).filter(Scenario.id == scenario_id).first()
    if not scenario:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scenario not found"
        )
    
    # Validate org if visibility is "org"
    if visibility == "org":
        if not org_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="org_id is required when visibility=org"
            )
        org = db.query(Organization).filter(Organization.id == org_id).first()
        if not org:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Organization not found"
            )
        scenario.org_id = org_id
    else:
        scenario.org_id = None
    
    scenario.visibility = visibility
    db.commit()
    db.refresh(scenario)
    
    return {
        "id": scenario.id,
        "message": f"Scenario visibility updated to {visibility}",
        "visibility": scenario.visibility
    }

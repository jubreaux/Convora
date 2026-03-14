from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_
from app.database import get_db
from app.models import Scenario, Objective, PersonalityTemplate, TraitSet, ScenarioContext, User, OrgMember
from app.schemas import ScenarioListResponse, ScenarioDetailResponse, ScenarioCreate, ObjectiveResponse
from app.utils import get_current_user, require_admin
import random

router = APIRouter(prefix="/api/scenarios", tags=["scenarios"])


def _get_user_org_ids(user: User, db: Session) -> list[int]:
    """Get all organization IDs the user is an active member of."""
    org_memberships = db.query(OrgMember).filter(
        OrgMember.user_id == user.id,
        OrgMember.is_active == True
    ).all()
    return [member.org_id for member in org_memberships]


def _build_visibility_filter(current_user: User, db: Session):
    """Build the SQLAlchemy filter for scenario visibility based on current user."""
    user_org_ids = _get_user_org_ids(current_user, db)
    
    # A scenario is visible if:
    # 1. It's "default" (platform-provided) or "public" (universally public)
    # 2. It's "personal" and created by the current user
    # 3. It's "org" and the user is a member of that organization
    return or_(
        Scenario.visibility.in_(["default", "public"]),  # Platform & public scenarios
        Scenario.created_by_user_id == current_user.id,  # User's personal scenarios
        Scenario.org_id.in_(user_org_ids) if user_org_ids else False  # User's org scenarios
    )


@router.get("", response_model=list[ScenarioListResponse])
async def list_scenarios(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """List all visible scenarios for the current user.
    
    Visibility rules:
    - "default" and "public" scenarios: always visible
    - "personal" scenarios: only if created by current user
    - "org" scenarios: only if user is a member of that organization
    """
    visibility_filter = _build_visibility_filter(current_user, db)
    scenarios = db.query(Scenario).filter(visibility_filter).all()
    return [ScenarioListResponse.model_validate(s) for s in scenarios]


@router.get("/random", response_model=ScenarioListResponse)
async def get_random_scenario(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Get a random visible scenario for the current user."""
    visibility_filter = _build_visibility_filter(current_user, db)
    scenarios = db.query(Scenario).filter(visibility_filter).all()
    
    if not scenarios:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No scenarios available"
        )
    
    return ScenarioListResponse.model_validate(random.choice(scenarios))


@router.get("/{scenario_id}", response_model=ScenarioDetailResponse)
async def get_scenario(scenario_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Get full scenario details if user has access.
    
    Access granted if:
    - Scenario is "default" or "public"
    - User created the scenario (visibility="personal")
    - User is in the organization and visibility="org"
    """
    scenario = db.query(Scenario).filter(Scenario.id == scenario_id).first()
    if not scenario:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scenario not found"
        )
    
    # Check visibility using standard filter
    visibility_filter = _build_visibility_filter(current_user, db)
    # Re-apply the specific scenario ID filter
    query = db.query(Scenario).filter(Scenario.id == scenario_id, visibility_filter)
    
    if not query.first():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied"
        )
    
    return ScenarioDetailResponse.model_validate(scenario)


@router.post("", response_model=ScenarioDetailResponse)
async def create_scenario(
    scenario_data: ScenarioCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a new custom scenario (user or admin).
    
    If personality_template_id, trait_set_id, or scenario_context_id are omitted,
    they will be auto-assigned to the first available record in each table.
    """
    # Auto-select first if not provided
    personality_id = scenario_data.personality_template_id
    if personality_id is None:
        first_personality = db.query(PersonalityTemplate).first()
        if not first_personality:
            raise HTTPException(status_code=400, detail="No PersonalityTemplate available")
        personality_id = first_personality.id
    else:
        first_personality = db.query(PersonalityTemplate).filter(
            PersonalityTemplate.id == personality_id
        ).first()
        if not first_personality:
            raise HTTPException(status_code=400, detail="Invalid personality_template_id")
    
    trait_id = scenario_data.trait_set_id
    if trait_id is None:
        first_trait = db.query(TraitSet).first()
        if not first_trait:
            raise HTTPException(status_code=400, detail="No TraitSet available")
        trait_id = first_trait.id
    else:
        first_trait = db.query(TraitSet).filter(
            TraitSet.id == trait_id
        ).first()
        if not first_trait:
            raise HTTPException(status_code=400, detail="Invalid trait_set_id")
    
    context_id = scenario_data.scenario_context_id
    if context_id is None:
        first_context = db.query(ScenarioContext).first()
        if not first_context:
            raise HTTPException(status_code=400, detail="No ScenarioContext available")
        context_id = first_context.id
    else:
        first_context = db.query(ScenarioContext).filter(
            ScenarioContext.id == context_id
        ).first()
        if not first_context:
            raise HTTPException(status_code=400, detail="Invalid scenario_context_id")
    
    # Create scenario
    new_scenario = Scenario(
        title=scenario_data.title,
        disc_type=scenario_data.disc_type,
        personality_template_id=personality_id,
        trait_set_id=trait_id,
        scenario_context_id=context_id,
        ai_system_prompt=scenario_data.ai_system_prompt,
        visibility="personal",  # User-created scenarios start private
        created_by_user_id=current_user.id
    )
    db.add(new_scenario)
    db.flush()  # Get the ID without committing
    
    # Create objectives
    for obj_data in scenario_data.objectives:
        objective = Objective(
            scenario_id=new_scenario.id,
            label=obj_data.label,
            description=obj_data.description,
            max_points=obj_data.max_points
        )
        db.add(objective)
    
    db.commit()
    db.refresh(new_scenario)
    return ScenarioDetailResponse.model_validate(new_scenario)


@router.put("/{scenario_id}", response_model=ScenarioDetailResponse)
async def update_scenario(
    scenario_id: int,
    scenario_data: ScenarioCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update a custom scenario (only creator or admin).
    
    If personality_template_id, trait_set_id, or scenario_context_id are omitted,
    they will be auto-assigned to the first available record in each table.
    """
    scenario = db.query(Scenario).filter(Scenario.id == scenario_id).first()
    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")
    
    if scenario.created_by_user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Auto-select first if not provided
    personality_id = scenario_data.personality_template_id
    if personality_id is None:
        first_personality = db.query(PersonalityTemplate).first()
        if not first_personality:
            raise HTTPException(status_code=400, detail="No PersonalityTemplate available")
        personality_id = first_personality.id
    else:
        first_personality = db.query(PersonalityTemplate).filter(
            PersonalityTemplate.id == personality_id
        ).first()
        if not first_personality:
            raise HTTPException(status_code=400, detail="Invalid personality_template_id")
    
    trait_id = scenario_data.trait_set_id
    if trait_id is None:
        first_trait = db.query(TraitSet).first()
        if not first_trait:
            raise HTTPException(status_code=400, detail="No TraitSet available")
        trait_id = first_trait.id
    else:
        first_trait = db.query(TraitSet).filter(
            TraitSet.id == trait_id
        ).first()
        if not first_trait:
            raise HTTPException(status_code=400, detail="Invalid trait_set_id")
    
    context_id = scenario_data.scenario_context_id
    if context_id is None:
        first_context = db.query(ScenarioContext).first()
        if not first_context:
            raise HTTPException(status_code=400, detail="No ScenarioContext available")
        context_id = first_context.id
    else:
        first_context = db.query(ScenarioContext).filter(
            ScenarioContext.id == context_id
        ).first()
        if not first_context:
            raise HTTPException(status_code=400, detail="Invalid scenario_context_id")
    
    # Update fields
    scenario.title = scenario_data.title
    scenario.disc_type = scenario_data.disc_type
    scenario.personality_template_id = personality_id
    scenario.trait_set_id = trait_id
    scenario.scenario_context_id = context_id
    scenario.ai_system_prompt = scenario_data.ai_system_prompt
    
    # Update objectives (delete old, add new)
    db.query(Objective).filter(Objective.scenario_id == scenario_id).delete()
    for obj_data in scenario_data.objectives:
        objective = Objective(
            scenario_id=scenario.id,
            label=obj_data.label,
            description=obj_data.description,
            max_points=obj_data.max_points
        )
        db.add(objective)
    
    db.commit()
    db.refresh(scenario)
    return ScenarioDetailResponse.model_validate(scenario)


@router.delete("/{scenario_id}")
async def delete_scenario(
    scenario_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a custom scenario (only creator or admin)."""
    scenario = db.query(Scenario).filter(Scenario.id == scenario_id).first()
    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")
    
    if scenario.created_by_user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Access denied")
    
    db.delete(scenario)
    db.commit()
    return {"ok": True}

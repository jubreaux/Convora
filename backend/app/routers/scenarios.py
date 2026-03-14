from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import Scenario, Objective, PersonalityTemplate, TraitSet, ScenarioContext, User
from app.schemas import ScenarioListResponse, ScenarioDetailResponse, ScenarioCreate, ObjectiveResponse
from app.utils import get_current_user, require_admin
import random

router = APIRouter(prefix="/api/scenarios", tags=["scenarios"])


@router.get("", response_model=list[ScenarioListResponse])
async def list_scenarios(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """List all public scenarios + user's own private scenarios."""
    public_scenarios = db.query(Scenario).filter(Scenario.visibility == "public").all()
    user_scenarios = db.query(Scenario).filter(
        Scenario.created_by_user_id == current_user.id
    ).all()
    
    scenarios = public_scenarios + user_scenarios
    return [ScenarioListResponse.model_validate(s) for s in scenarios]


@router.get("/random", response_model=ScenarioListResponse)
async def get_random_scenario(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Get a random scenario (public or user's own)."""
    # Get public scenarios
    public_scenarios = db.query(Scenario).filter(Scenario.visibility == "public").all()
    
    # Also include user's own scenarios
    user_scenarios = db.query(Scenario).filter(
        Scenario.created_by_user_id == current_user.id
    ).all()
    
    # Combine lists
    all_scenarios = public_scenarios + user_scenarios
    
    if not all_scenarios:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No scenarios available"
        )
    
    return ScenarioListResponse.model_validate(random.choice(all_scenarios))


@router.get("/{scenario_id}", response_model=ScenarioDetailResponse)
async def get_scenario(scenario_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Get full scenario details (only if public or user is creator)."""
    scenario = db.query(Scenario).filter(Scenario.id == scenario_id).first()
    if not scenario:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scenario not found"
        )
    
    # Check permissions: allow if public or user is creator
    if scenario.visibility != "public" and scenario.created_by_user_id != current_user.id:
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
    """Create a new custom scenario (user or admin)."""
    # Validate relationships exist
    personality = db.query(PersonalityTemplate).filter(
        PersonalityTemplate.id == scenario_data.personality_template_id
    ).first()
    if not personality:
        raise HTTPException(status_code=400, detail="Invalid personality_template_id")
    
    trait_set = db.query(TraitSet).filter(
        TraitSet.id == scenario_data.trait_set_id
    ).first()
    if not trait_set:
        raise HTTPException(status_code=400, detail="Invalid trait_set_id")
    
    context = db.query(ScenarioContext).filter(
        ScenarioContext.id == scenario_data.scenario_context_id
    ).first()
    if not context:
        raise HTTPException(status_code=400, detail="Invalid scenario_context_id")
    
    # Create scenario
    new_scenario = Scenario(
        title=scenario_data.title,
        disc_type=scenario_data.disc_type,
        personality_template_id=scenario_data.personality_template_id,
        trait_set_id=scenario_data.trait_set_id,
        scenario_context_id=scenario_data.scenario_context_id,
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
    """Update a custom scenario (only creator or admin)."""
    scenario = db.query(Scenario).filter(Scenario.id == scenario_id).first()
    if not scenario:
        raise HTTPException(status_code=404, detail="Scenario not found")
    
    if scenario.created_by_user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Update fields
    scenario.title = scenario_data.title
    scenario.disc_type = scenario_data.disc_type
    scenario.personality_template_id = scenario_data.personality_template_id
    scenario.trait_set_id = scenario_data.trait_set_id
    scenario.scenario_context_id = scenario_data.scenario_context_id
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

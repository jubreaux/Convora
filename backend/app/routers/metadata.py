"""Metadata router — reference data endpoints (personality templates, trait sets, scenario contexts).

Locked to authenticated users (not admin-only) since this is read-only reference data.
Used by scenario creation/editing forms in the mobile app.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import PersonalityTemplate, TraitSet, ScenarioContext
from app.utils import get_current_user
from app.schemas import PersonalityTemplateResponse, TraitSetResponse, ScenarioContextResponse
from typing import List

router = APIRouter(prefix="/api/metadata", tags=["metadata"])


@router.get("/personality-templates", response_model=List[PersonalityTemplateResponse])
async def list_personality_templates(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """List all personality templates for scenario creation/editing forms.
    
    Available to all authenticated users (not admin-only).
    """
    templates = db.query(PersonalityTemplate).order_by(PersonalityTemplate.id).all()
    return templates


@router.get("/trait-sets", response_model=List[TraitSetResponse])
async def list_trait_sets(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """List all trait sets for scenario creation/editing forms.
    
    Available to all authenticated users (not admin-only).
    """
    trait_sets = db.query(TraitSet).order_by(TraitSet.trait_set_number).all()
    return trait_sets


@router.get("/scenario-contexts", response_model=List[ScenarioContextResponse])
async def list_scenario_contexts(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """List all scenario contexts for scenario creation/editing forms.
    
    Available to all authenticated users (not admin-only).
    """
    contexts = db.query(ScenarioContext).order_by(ScenarioContext.name).all()
    return contexts

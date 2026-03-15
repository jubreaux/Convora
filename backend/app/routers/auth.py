from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.database import get_db
from app.models import User, Organization, OrgMember
from app.schemas import UserRegister, UserLogin, UserSelfUpdate, UserPasswordReset, TokenResponse, UserResponse, OrgMemberCreate, OrgMemberResponse, OrgMemberStatsResponse
from app.utils import hash_password, verify_password, create_access_token, get_current_user
from datetime import timedelta, datetime
from app.config import get_settings

router = APIRouter(prefix="/api/auth", tags=["auth"])
settings = get_settings()


def _build_user_response(user: User, db: Session) -> UserResponse:
    """Build a UserResponse with org info populated from OrgMember."""
    org_member = db.query(OrgMember).filter(OrgMember.user_id == user.id).first()
    
    org_id = None
    org_role = None
    
    if org_member:
        org_id = org_member.org_id
        org_role = org_member.org_role
    
    return UserResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        role=user.role,
        must_reset_password=user.must_reset_password,
        org_id=org_id,
        org_role=org_role,
        created_at=user.created_at
    )


@router.post("/register", response_model=TokenResponse)
async def register(user_data: UserRegister, db: Session = Depends(get_db)):
    """Register a new user (personal or company account)."""
    # Check if user already exists
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    if user_data.account_type == "company" and not user_data.company_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="company_name is required for company accounts"
        )
    
    # Create new user
    hashed_password = hash_password(user_data.password)
    new_user = User(
        email=user_data.email,
        password_hash=hashed_password,
        name=user_data.name,
        role="user"
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # If company account, create Organization and OrgMember
    if user_data.account_type == "company":
        new_org = Organization(
            name=user_data.company_name,
            is_active=True
        )
        db.add(new_org)
        db.commit()
        db.refresh(new_org)
        
        org_member = OrgMember(
            org_id=new_org.id,
            user_id=new_user.id,
            org_role="org_admin",
            is_active=True
        )
        db.add(org_member)
        db.commit()
    
    # Create token
    access_token = create_access_token(
        data={"sub": str(new_user.id)},
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    
    # Build user response with org info
    user_response = _build_user_response(new_user, db)
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": user_response
    }


@router.post("/login", response_model=TokenResponse)
async def login(user_data: UserLogin, db: Session = Depends(get_db)):
    """Login user and return JWT token."""
    print(f"[LOGIN] Received request: email={user_data.email}, password_len={len(user_data.password)}")
    
    # Find user by email (case-insensitive)
    user = db.query(User).filter(User.email == user_data.email.lower()).first()
    if not user:
        print(f"[LOGIN] User not found: {user_data.email}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )
    
    # Verify password
    if not verify_password(user_data.password, user.password_hash):
        print(f"[LOGIN] Invalid password for user: {user_data.email}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )
    
    print(f"[LOGIN] User authenticated: {user.email} (ID: {user.id})")
    
    # Create token
    access_token = create_access_token(
        data={"sub": str(user.id)},
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    
    # Build user response with org info
    user_response = _build_user_response(user, db)
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": user_response
    }


@router.get("/me", response_model=UserResponse)
async def me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Get current user from token."""
    user_response = _build_user_response(current_user, db)
    return user_response


@router.put("/me", response_model=UserResponse)
async def update_me(
    update_data: UserSelfUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update current user's profile (name and email only)."""
    # Re-query the user in the current session to avoid session mismatch
    # (current_user comes from a different session context via dependency)
    user = db.query(User).filter(User.id == current_user.id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Check if new email already exists (if email is being updated)
    if update_data.email and update_data.email != user.email:
        existing_user = db.query(User).filter(User.email == update_data.email).first()
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already in use"
            )
        user.email = update_data.email
    
    # Update name if provided
    if update_data.name is not None:
        user.name = update_data.name
    
    # Update voice preference if explicitly included in request (supports clearing to None)
    if 'preferred_voice' in update_data.model_fields_set:
        user.preferred_voice = update_data.preferred_voice
    
    db.commit()
    db.refresh(user)
    
    # Build response with org info
    user_response = _build_user_response(user, db)
    return user_response


@router.put("/reset-password", response_model=UserResponse)
async def reset_password(
    reset_data: UserPasswordReset,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Allow a user to reset their password."""
    # Re-query the user in the current session
    user = db.query(User).filter(User.id == current_user.id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Verify current password
    if not verify_password(reset_data.current_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Current password is incorrect"
        )
    
    # Update password
    user.password_hash = hash_password(reset_data.new_password)
    user.must_reset_password = False
    
    db.commit()
    db.refresh(user)
    
    # Build response with org info
    user_response = _build_user_response(user, db)
    return user_response


# ===== Organization Member Management (org_admin only) =====

def _require_org_admin(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Dependency to ensure user is an org admin."""
    org_member = db.query(OrgMember).filter(
        OrgMember.user_id == current_user.id,
        OrgMember.is_active == True
    ).first()
    
    if not org_member or org_member.org_role != "org_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only organization admins can access this resource"
        )
    
    return org_member


@router.get("/org/members", response_model=list[OrgMemberResponse])
async def list_org_members(
    db: Session = Depends(get_db),
    org_member: OrgMember = Depends(_require_org_admin)
):
    """List all active members of the user's organization."""
    members = db.query(OrgMember).filter(
        OrgMember.org_id == org_member.org_id,
        OrgMember.is_active == True
    ).order_by(OrgMember.joined_at.desc()).all()

    result = []
    for m in members:
        user = db.query(User).filter(User.id == m.user_id).first()
        response = OrgMemberResponse(
            id=m.id,
            user_id=m.user_id,
            org_role=m.org_role,
            is_active=m.is_active,
            joined_at=m.joined_at,
            user_email=user.email if user else None,
            user_name=user.name if user else None,
        )
        result.append(response)

    return result


@router.post("/org/members", response_model=OrgMemberResponse)
async def provision_org_member(
    member_data: OrgMemberCreate,
    db: Session = Depends(get_db),
    org_member: OrgMember = Depends(_require_org_admin)
):
    """Provision a new organization member."""
    # Check if email already exists
    existing_user = db.query(User).filter(User.email == member_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Create new user with temp password
    new_user = User(
        email=member_data.email,
        name=member_data.name,
        password_hash=hash_password(member_data.temp_password),
        role="user",
        must_reset_password=True  # Force password reset on first login
    )
    db.add(new_user)
    db.flush()  # Get the new user ID
    
    # Add to organization
    new_member = OrgMember(
        org_id=org_member.org_id,
        user_id=new_user.id,
        org_role=member_data.org_role
    )
    db.add(new_member)
    db.commit()
    db.refresh(new_member)
    
    return OrgMemberResponse.from_orm(new_member)


@router.delete("/org/members/{user_id}")
async def deactivate_org_member(
    user_id: int,
    db: Session = Depends(get_db),
    org_member: OrgMember = Depends(_require_org_admin)
):
    """Deactivate an organization member."""
    # Find the member to deactivate
    member_to_remove = db.query(OrgMember).filter(
        OrgMember.user_id == user_id,
        OrgMember.org_id == org_member.org_id,
        OrgMember.is_active == True
    ).first()
    
    if not member_to_remove:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Member not found"
        )
    
    # Cannot remove the only org_admin
    if member_to_remove.org_role == "org_admin":
        admin_count = db.query(OrgMember).filter(
            OrgMember.org_id == org_member.org_id,
            OrgMember.org_role == "org_admin",
            OrgMember.is_active == True
        ).count()
        
        if admin_count <= 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot remove the last organization admin"
            )
    
    # Deactivate (soft delete) the member
    member_to_remove.is_active = False
    db.commit()
    
    return {"ok": True, "message": "Member deactivated"}


@router.get("/org/analytics", response_model=list[OrgMemberStatsResponse])
async def get_org_analytics(
    db: Session = Depends(get_db),
    org_member: OrgMember = Depends(_require_org_admin)
):
    """Get performance analytics for all members of the organization."""
    from app.models import Session as TrainingSession

    members = db.query(OrgMember).filter(
        OrgMember.org_id == org_member.org_id,
        OrgMember.is_active == True
    ).all()

    result = []
    for m in members:
        user = db.query(User).filter(User.id == m.user_id).first()
        if not user:
            continue

        sessions = db.query(TrainingSession).filter(
            TrainingSession.user_id == m.user_id,
            TrainingSession.status == "completed"
        ).all()

        total = len(sessions)
        avg_score = round(sum(s.score for s in sessions) / total, 1) if total > 0 else 0.0
        best_score = max((s.score for s in sessions), default=0)
        appts = sum(1 for s in sessions if s.appointment_set)
        appt_rate = round((appts / total) * 100, 1) if total > 0 else 0.0

        result.append(OrgMemberStatsResponse(
            user_id=m.user_id,
            user_name=user.name,
            user_email=user.email,
            org_role=m.org_role,
            total_sessions=total,
            avg_score=avg_score,
            best_score=best_score,
            appointment_rate=appt_rate,
            joined_at=m.joined_at,
        ))

    return result

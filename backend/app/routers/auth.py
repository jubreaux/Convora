from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, Organization, OrgMember
from app.schemas import UserRegister, UserLogin, UserSelfUpdate, UserPasswordReset, TokenResponse, UserResponse
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

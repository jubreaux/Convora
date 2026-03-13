from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer
from starlette.requests import Request
from sqlalchemy.orm import Session
from app.config import get_settings
from app.models import User

settings = get_settings()

# Password hashing - using argon2 as primary with bcrypt fallback
try:
    pwd_context = CryptContext(schemes=["argon2", "bcrypt"], deprecated="auto")
except Exception:
    # Fallback if argon2 not available
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# HTTP Bearer for FastAPI dependency
security = HTTPBearer()


def hash_password(password: str) -> str:
    """Hash a password using bcrypt."""
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain password against its hash."""
    return pwd_context.verify(plain_password, hashed_password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a JWT access token."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    print(f"[TOKEN] Creating token with: sub={to_encode.get('sub')}, exp={to_encode.get('exp')}")
    print(f"[TOKEN] JWT_SECRET length: {len(settings.JWT_SECRET)}")
    encoded_jwt = jwt.encode(to_encode, settings.JWT_SECRET, algorithm=settings.ALGORITHM)
    print(f"[TOKEN] Token created: {encoded_jwt[:50]}...")
    return encoded_jwt


def decode_token(token: str) -> dict:
    """Decode and validate a JWT token."""
    try:
        print(f"[DECODE] Attempting to decode token...")
        print(f"[DECODE] JWT_SECRET length: {len(settings.JWT_SECRET)}")
        print(f"[DECODE] Algorithm: {settings.ALGORITHM}")
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.ALGORITHM])
        print(f"[DECODE] Token decoded successfully: sub={payload.get('sub')}, exp={payload.get('exp')}")
        return payload
    except JWTError as e:
        print(f"[DECODE] JWTError: {str(e)}")
        return None
    except Exception as e:
        print(f"[DECODE] Unexpected error: {str(e)}")
        return None


async def get_current_user(request: Request) -> User:
    """FastAPI dependency to extract and validate the current user from JWT."""
    from app.database import SessionLocal

    auth_header = request.headers.get("Authorization")
    print(f"[AUTH] Authorization header: {auth_header}")
    
    if not auth_header or not auth_header.startswith("Bearer "):
        print(f"[AUTH] Missing or invalid Authorization header")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
        )

    token = auth_header.split(" ")[1]
    payload = decode_token(token)

    if payload is None:
        print(f"[AUTH] Token decode failed")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    user_id = payload.get("sub")
    if user_id is None:
        print(f"[AUTH] Token missing subject claim")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing subject claim",
        )

    db_local = SessionLocal()
    try:
        user = db_local.query(User).filter(User.id == int(user_id)).first()
        if user is None:
            print(f"[AUTH] User not found: {user_id}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found",
            )
        print(f"[AUTH] User authenticated: {user.email} (ID: {user.id})")
        return user
    finally:
        db_local.close()


async def require_admin(current_user: User = Depends(get_current_user)) -> User:
    """FastAPI dependency to enforce admin role."""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return current_user

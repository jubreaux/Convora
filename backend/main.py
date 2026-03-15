from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import engine, Base
from app.models import (
    User, PersonalityTemplate, TraitSet, ScenarioContext,
    FinetuneExample, Scenario, Objective, Session, SessionObjective, Message
)
from app.routers import auth, scenarios, sessions, admin, metadata
from seed.load_seed import seed_database
import uvicorn


# Create all tables
Base.metadata.create_all(bind=engine)

# Seed database if needed
try:
    seed_database()
except Exception as e:
    print(f"Note: Seed data not loaded (this is OK on first run): {e}")


# Create FastAPI app
app = FastAPI(
    title="Convora Backend API",
    version="0.1.0",
    description="ISA Training Platform with AI-Powered Blind Role-Play"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify allowed origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(scenarios.router)
app.include_router(sessions.router)
app.include_router(admin.router)
app.include_router(metadata.router)


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "ok", "version": "0.1.0"}


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "app": "Convora Backend API",
        "version": "0.1.0",
        "docs": "/docs"
    }


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, log_level="info")

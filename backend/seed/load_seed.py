"""Seed database with initial data from JSON files."""

import json
import os
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine
from app.models import Base, PersonalityTemplate, TraitSet, ScenarioContext, FinetuneExample, User, Scenario


def create_test_users(db: Session):
    """Create test user accounts."""
    try:
        # Import here to avoid circular imports
        from app.utils import hash_password
        
        test_users = [
            {"email": "test@example.com", "name": "Test User", "password": "password123"},
            {"email": "demo@example.com", "name": "Demo User", "password": "demo123"},
        ]
        
        created_count = 0
        for user_data in test_users:
            if db.query(User).filter(User.email == user_data["email"]).first() is None:
                user = User(
                    email=user_data["email"],
                    name=user_data["name"],
                    password_hash=hash_password(user_data["password"])
                )
                db.add(user)
                created_count += 1
        
        if created_count > 0:
            db.commit()
            print(f"✓ Created {created_count} test user accounts")
            return created_count
        return 0
    except Exception as e:
        print(f"✗ Error creating test users: {e}")
        db.rollback()
        raise


def seed_database():
    """Load seed data from JSON files."""
    
    # Create tables
    Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    
    try:
        # Check if already seeded
        if db.query(PersonalityTemplate).first() is not None:
            print("Database already seeded. Skipping.")
            # Still try to create test users if they don't exist
            if db.query(User).first() is None:
                create_test_users(db)
            return
        
        print("Seeding database...")
        
        # Helper to read JSON files with encoding fallbacks
        def _read_json_file(path):
            if not os.path.exists(path):
                return None
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except UnicodeDecodeError:
                try:
                    with open(path, 'r', encoding='utf-16') as f:
                        return json.load(f)
                except UnicodeDecodeError:
                    with open(path, 'rb') as f:
                        raw = f.read()
                        text = raw.decode('utf-8', errors='replace')
                        try:
                            return json.loads(text)
                        except Exception as e:
                            print(f"✗ Failed to parse JSON at {path}: {e}")
                            return None
            except json.JSONDecodeError as e:
                print(f"✗ JSON decode error for {path}: {e}")
                return None
            except Exception as e:
                print(f"✗ Error reading {path}: {e}")
                return None

        # Load personalities
        personalities_path = os.path.join(
            os.path.dirname(__file__),
            "../SeedData/Personalities.json"
        )
        personalities_data = _read_json_file(personalities_path)
        if personalities_data:
            for p in personalities_data.get("Personalities", []):
                personality = PersonalityTemplate(
                    occupation=p.get("Occupation", ""),
                    recreation=p.get("Recreation"),
                    family=p.get("Family"),
                    pets=p.get("Pets"),
                    transaction_type=p.get("TransactionType", ""),
                    buy_criteria=p.get("BuyCriteria"),
                    sell_criteria=p.get("SellCriteria"),
                    surface_motivation=p.get("Motivation", "").split(", Hidden - ")[0].replace("Surface - ", ""),
                    hidden_motivation=p.get("Motivation", "").split(", Hidden - ")[1] if ", Hidden - " in p.get("Motivation", "") else None,
                    timeframe=p.get("TimeFrame"),
                    red_flags=p.get("RedFlags")
                )
                db.add(personality)
            db.commit()
            print(f"✓ Loaded {len(personalities_data.get('Personalities', []))} personalities")
        
        # Load trait sets
        traits_path = os.path.join(
            os.path.dirname(__file__),
            "../SeedData/Traits.json"
        )
        traits_data = _read_json_file(traits_path)
        if traits_data:
            for t in traits_data.get("Traits", []):
                trait_set = TraitSet(
                    trait_set_number=t.get("TraitSet", 0),
                    trait_1=t.get("Traits", [])[0] if len(t.get("Traits", [])) > 0 else "",
                    trait_2=t.get("Traits", [])[1] if len(t.get("Traits", [])) > 1 else "",
                    trait_3=t.get("Traits", [])[2] if len(t.get("Traits", [])) > 2 else ""
                )
                db.add(trait_set)
            db.commit()
            print(f"✓ Loaded {len(traits_data.get('Traits', []))} trait sets")
        
        # Load scenario contexts
        scenarios_path = os.path.join(
            os.path.dirname(__file__),
            "../SeedData/scenarios.json"
        )
        scenarios_data = _read_json_file(scenarios_path)
        if scenarios_data:
            for context_name in scenarios_data.get("Scenarios", []):
                context = ScenarioContext(name=context_name)
                db.add(context)
            db.commit()
            print(f"✓ Loaded {len(scenarios_data.get('Scenarios', []))} scenario contexts")
        
        # Load finetune examples
        finetune_path = os.path.join(
            os.path.dirname(__file__),
            "../SeedData/finetune.jsonl"
        )
        if os.path.exists(finetune_path):
            count = 0
            # Try multiple encodings and fall back to a safe decode with replacement
            lines = []
            try:
                with open(finetune_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
            except UnicodeDecodeError:
                try:
                    with open(finetune_path, 'r', encoding='utf-16') as f:
                        lines = f.readlines()
                except UnicodeDecodeError:
                    with open(finetune_path, 'rb') as f:
                        raw = f.read()
                        text = raw.decode('utf-8', errors='replace')
                        lines = text.splitlines()

            for line in lines:
                if line and line.strip():
                    try:
                        data = json.loads(line)
                        example = FinetuneExample(
                            prompt=data.get("prompt", ""),
                            completion=data.get("completion", "")
                        )
                        db.add(example)
                        count += 1
                    except Exception as e:
                        print(f"✗ Skipping invalid finetune line: {e}")
            db.commit()
            print(f"✓ Loaded {count} finetune examples")
        
        # Create test user accounts
        create_test_users(db)
        
        # Create public test scenarios (if any users exist)
        if db.query(User).first() is not None:
            test_scenarios = [
                {
                    "title": "Real Estate Sales Call",
                    "disc_type": "D",
                    "personality_template_id": 1,
                    "trait_set_id": 1,
                    "scenario_context_id": 1,
                    "ai_system_prompt": "You are a professional sales consultant handling a real estate inquiry.",
                    "is_public": True,
                },
                {
                    "title": "Customer Support Interaction",
                    "disc_type": "I",
                    "personality_template_id": 2,
                    "trait_set_id": 2,
                    "scenario_context_id": 1,
                    "ai_system_prompt": "You are a friendly customer support representative.",
                    "is_public": True,
                },
            ]
            
            created_scenarios = 0
            test_user = db.query(User).filter(User.email == "test@example.com").first()
            if test_user:
                for scenario_data in test_scenarios:
                    if db.query(Scenario).filter(Scenario.title == scenario_data["title"]).first() is None:
                        scenario = Scenario(
                            title=scenario_data["title"],
                            disc_type=scenario_data["disc_type"],
                            personality_template_id=scenario_data.get("personality_template_id", 1),
                            trait_set_id=scenario_data.get("trait_set_id", 1),
                            scenario_context_id=scenario_data.get("scenario_context_id", 1),
                            ai_system_prompt=scenario_data.get("ai_system_prompt", ""),
                            is_public=scenario_data["is_public"],
                            created_by_user_id=test_user.id,
                        )
                        db.add(scenario)
                        created_scenarios += 1
                
                if created_scenarios > 0:
                    db.commit()
                    print(f"✓ Created {created_scenarios} test scenarios")
        
        print("✓ Database seeding complete!")
    
    except Exception as e:
        print(f"✗ Error seeding database: {e}")
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()

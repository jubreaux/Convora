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
            {"email": "admin@example.com", "name": "Admin User", "password": "password123", "role": "admin"},
            {"email": "test@example.com", "name": "Test User", "password": "password123", "role": "user"},
            {"email": "demo@example.com", "name": "Demo User", "password": "demo123", "role": "user"},
        ]
        
        created_count = 0
        for user_data in test_users:
            existing_user = db.query(User).filter(User.email == user_data["email"]).first()
            if existing_user is None:
                user = User(
                    email=user_data["email"],
                    name=user_data["name"],
                    password_hash=hash_password(user_data["password"]),
                    role=user_data.get("role", "user")
                )
                db.add(user)
                created_count += 1
            else:
                # Update existing user password, name, and role
                existing_user.password_hash = hash_password(user_data["password"])
                existing_user.name = user_data["name"]
                existing_user.role = user_data.get("role", "user")
                created_count += 1
        
        if created_count > 0:
            db.commit()
            print(f"✓ Updated/Created {created_count} test user accounts")
            return created_count
        return 0
    except Exception as e:
        print(f"✗ Error creating test users: {e}")
        db.rollback()
        raise


def seed_scenarios(db: Session, _read_json_file=None):
    """Seed scenarios from ScenarioDefinitions.json. Safe to call on existing DB."""
    if _read_json_file is None:
        # Use the function from seed_database scope if available
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
    
    try:
        # Count existing scenarios
        existing_count = db.query(Scenario).count()
        target_count = 8
        
        if existing_count >= target_count:
            print(f"✓ Scenarios already seeded ({existing_count} >= {target_count}). Skipping.")
            return
        
        # Load scenario definitions
        scenarios_path = os.path.join(
            os.path.dirname(__file__),
            "../SeedData/ScenarioDefinitions.json"
        )
        scenarios_data = _read_json_file(scenarios_path)
        
        if not scenarios_data:
            print(f"✗ Could not load ScenarioDefinitions.json from {scenarios_path}")
            return
        
        # Get test user
        test_user = db.query(User).filter(User.email == "test@example.com").first()
        if not test_user:
            print("✗ Test user not found. Cannot seed scenarios.")
            return
        
        created_count = 0
        for scenario_def in scenarios_data.get("Scenarios", []):
            # Check if scenario already exists by title
            if db.query(Scenario).filter(Scenario.title == scenario_def.get("title")).first() is not None:
                continue
            
            # Resolve foreign keys by name/number lookups
            try:
                # Lookup ScenarioContext by name
                context = db.query(ScenarioContext).filter(
                    ScenarioContext.name == scenario_def.get("context_name")
                ).first()
                if not context:
                    print(f"✗ ScenarioContext not found: {scenario_def.get('context_name')}")
                    continue
                
                # Lookup TraitSet by number
                trait_set = db.query(TraitSet).filter(
                    TraitSet.trait_set_number == scenario_def.get("trait_set_number")
                ).first()
                if not trait_set:
                    print(f"✗ TraitSet not found: {scenario_def.get('trait_set_number')}")
                    continue
                
                # Lookup PersonalityTemplate by occupation
                personality = db.query(PersonalityTemplate).filter(
                    PersonalityTemplate.occupation == scenario_def.get("personality_occupation")
                ).first()
                if not personality:
                    print(f"✗ PersonalityTemplate not found: {scenario_def.get('personality_occupation')}")
                    continue
                
                # Create scenario
                scenario = Scenario(
                    title=scenario_def.get("title"),
                    disc_type=scenario_def.get("disc_type"),
                    personality_template_id=personality.id,
                    trait_set_id=trait_set.id,
                    scenario_context_id=context.id,
                    ai_system_prompt=scenario_def.get("ai_system_prompt", ""),
                    is_public=scenario_def.get("is_public", True),
                    created_by_user_id=test_user.id,
                )
                db.add(scenario)
                created_count += 1
            
            except Exception as e:
                print(f"✗ Error creating scenario '{scenario_def.get('title')}': {e}")
                continue
        
        if created_count > 0:
            db.commit()
            print(f"✓ Created {created_count} scenarios ({existing_count + created_count} total)")
        else:
            print("✓ All scenarios already exist.")
    
    except Exception as e:
        print(f"✗ Error seeding scenarios: {e}")
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
            print("Database already seeded. Skipping JSON sources.")
            # Always ensure test users exist and have correct roles
            create_test_users(db)
            # Always seed scenarios in case new ones are defined
            seed_scenarios(db)
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
        
        # Seed scenarios from definition file
        seed_scenarios(db)
        
        print("✓ Database seeding complete!")
    
    except Exception as e:
        print(f"✗ Error seeding database: {e}")
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()

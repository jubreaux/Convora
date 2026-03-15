#!/usr/bin/env python3
"""
Fix scenario visibility for public scenarios owned by admin on production database.
Checks and updates:
- visibility field (should be "public" or "default")
- created_at timestamp (set to current time if in future)
"""

import os
from datetime import datetime
from app.database import SessionLocal
from app.models import Scenario, User

def fix_prod_scenarios():
    """Fix visibility and timestamps for admin's public scenarios."""
    db = SessionLocal()
    try:
        # Get admin user
        admin = db.query(User).filter(User.email == "admin@example.com").first()
        if not admin:
            print("❌ Admin user not found!")
            return False

        print(f"✓ Found admin user: {admin.email} (ID: {admin.id})")

        # Find all scenarios owned by admin
        admin_scenarios = db.query(Scenario).filter(
            Scenario.created_by_user_id == admin.id
        ).all()

        if not admin_scenarios:
            print("✓ No scenarios found owned by admin")
            return True

        print(f"✓ Found {len(admin_scenarios)} scenario(s) owned by admin:")
        
        now = datetime.utcnow()
        fixed_count = 0

        for scenario in admin_scenarios:
            print(f"\n  Scenario ID {scenario.id}: '{scenario.title}'")
            print(f"    - Current visibility: {scenario.visibility}")
            print(f"    - Current created_at: {scenario.created_at}")
            
            # Check and fix visibility
            if scenario.visibility not in ["public", "default"]:
                print(f"    ⚠️  Fixing visibility from '{scenario.visibility}' → 'public'")
                scenario.visibility = "public"
                fixed_count += 1
            
            # Check and fix created_at timestamp  
            if scenario.created_at and scenario.created_at > now:
                print(f"    ⚠️  created_at is in the future! Fixing to now")
                scenario.created_at = now
                fixed_count += 1
            else:
                print(f"    ✓ Visibility and timestamp OK")

        if fixed_count > 0:
            db.commit()
            print(f"\n✅ Fixed {fixed_count} field(s) across scenarios")
            return True
        else:
            print(f"\n✓ All scenarios are already properly configured")
            return True

    except Exception as e:
        print(f"❌ Error: {e}")
        db.rollback()
        return False
    finally:
        db.close()

if __name__ == "__main__":
    print("🔧 Fixing production scenarios visibility...\n")
    success = fix_prod_scenarios()
    exit(0 if success else 1)

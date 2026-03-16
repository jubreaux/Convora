#!/usr/bin/env python3
"""Fix scenario ownership — assign all public/default scenarios to admin@example.com"""

import sys
from app.database import SessionLocal
from app.models import Scenario, User

def fix_scenario_ownership():
    """Reassign all public scenarios to admin user."""
    db = SessionLocal()
    try:
        # Get admin user
        admin = db.query(User).filter(User.email == "admin@example.com").first()
        if not admin:
            print("❌ Admin user not found!")
            return False

        # Find scenarios with public/default visibility that aren't owned by admin
        public_scenarios = db.query(Scenario).filter(
            (Scenario.visibility.in_(["public", "default"])) | 
            (Scenario.created_by_user_id == None)
        ).all()

        if not public_scenarios:
            print("✅ All public scenarios already properly owned")
            return True

        count = 0
        for scenario in public_scenarios:
            if scenario.created_by_user_id != admin.id:
                old_owner = scenario.created_by_user_id
                scenario.created_by_user_id = admin.id
                if scenario.visibility not in ["public", "default"]:
                    scenario.visibility = "default"
                count += 1
                print(f"  ✓ {scenario.title} (was owned by user {old_owner}, now {admin.id})")

        if count > 0:
            db.commit()
            print(f"\n✅ Fixed {count} scenario(s)")
            return True
        else:
            print("✅ All public scenarios already owned by admin")
            return True

    except Exception as e:
        print(f"❌ Error: {e}")
        db.rollback()
        return False
    finally:
        db.close()

if __name__ == "__main__":
    print("🔧 Fixing scenario ownership...\n")
    success = fix_scenario_ownership()
    sys.exit(0 if success else 1)

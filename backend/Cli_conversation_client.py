#!/usr/bin/env python3
"""
Convora CLI Chat Client - Manual backend testing tool
Allows users to interactively test training scenarios and conversation flows
"""

import requests
import json
import sys
from typing import Optional, Dict, Any
from datetime import datetime

# Colors for terminal output
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    GRAY = '\033[90m'


class ConvoraClient:
    """Interactive CLI client for Convora backend testing."""
    
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.auth_token: Optional[str] = None
        self.user_id: Optional[int] = None
        self.session_id: Optional[int] = None
        self.current_scenario: Optional[Dict] = None
        self.score = 0
        
    def print_header(self, text: str):
        """Print a formatted section header."""
        print(f"\n{Colors.BOLD}{Colors.HEADER}{'='*70}{Colors.ENDC}")
        print(f"{Colors.BOLD}{Colors.HEADER}  {text}{Colors.ENDC}")
        print(f"{Colors.BOLD}{Colors.HEADER}{'='*70}{Colors.ENDC}\n")
        
    def print_success(self, text: str):
        """Print success message."""
        print(f"{Colors.OKGREEN}✓ {text}{Colors.ENDC}")
        
    def print_error(self, text: str):
        """Print error message."""
        print(f"{Colors.FAIL}✗ {text}{Colors.ENDC}")
        
    def print_info(self, text: str):
        """Print info message."""
        print(f"{Colors.OKCYAN}ℹ {text}{Colors.ENDC}")
        
    def print_warning(self, text: str):
        """Print warning message."""
        print(f"{Colors.WARNING}⚠ {text}{Colors.ENDC}")
        
    def clear_screen(self):
        """Clear terminal screen."""
        print("\033[2J\033[H", end="")
        
    def welcome(self):
        """Display welcome banner."""
        self.clear_screen()
        print(f"""
{Colors.BOLD}{Colors.HEADER}
╔════════════════════════════════════════════════════════════════════╗
║                                                                    ║
║               🎯 CONVORA CLI CHAT CLIENT 🎯                       ║
║                                                                    ║
║               Real Estate Agent Training Simulator                ║
║                                                                    ║
║  {Colors.ENDC}{Colors.BOLD}Test Account:{Colors.HEADER}                                            ║
║  {Colors.ENDC}{Colors.BOLD}Email: test@example.com{Colors.HEADER}                           ║
║  {Colors.ENDC}{Colors.BOLD}Password: password123{Colors.HEADER}                                 ║
║                                                                    ║
╚════════════════════════════════════════════════════════════════════╝
{Colors.ENDC}
""")
        
    def login(self):
        """Authenticate user."""
        self.print_header("AUTHENTICATION")
        
        email = input(f"{Colors.BOLD}Email:{Colors.ENDC} ").strip()
        password = input(f"{Colors.BOLD}Password:{Colors.ENDC} ").strip()
        
        try:
            response = requests.post(
                f"{self.base_url}/api/auth/login",
                json={"email": email, "password": password},
                timeout=5
            )
            
            if response.status_code == 200:
                data = response.json()
                self.auth_token = data.get("access_token")
                self.user_id = data.get("user", {}).get("id")
                self.print_success(f"Logged in as {email}")
                return True
            else:
                self.print_error(f"Login failed: {response.json().get('detail', 'Unknown error')}")
                return False
        except requests.exceptions.ConnectionError:
            self.print_error("Cannot connect to backend. Is it running on localhost:8000?")
            return False
        except Exception as e:
            self.print_error(f"Login error: {str(e)}")
            return False
            
    def get_health(self) -> bool:
        """Check if backend is healthy."""
        try:
            response = requests.get(f"{self.base_url}/health", timeout=5)
            return response.status_code == 200
        except:
            return False
            
    def list_scenarios(self) -> bool:
        """List available scenarios and let user select one."""
        self.print_header("SELECT SCENARIO")
        
        try:
            headers = {"Authorization": f"Bearer {self.auth_token}"}
            response = requests.get(
                f"{self.base_url}/api/scenarios",
                headers=headers,
                timeout=5
            )
            
            if response.status_code != 200:
                self.print_error("Failed to load scenarios")
                return False
                
            scenarios = response.json()
            
            if not scenarios:
                self.print_error("No scenarios available")
                return False
                
            # Display scenarios with rich info
            for i, scenario in enumerate(scenarios[:10], 1):
                title = scenario.get('title', 'Untitled')
                disc = scenario.get('disc_type', '?')
                context = scenario.get('scenario_context', {}).get('name', 'N/A') if isinstance(scenario.get('scenario_context'), dict) else 'N/A'
                transaction = scenario.get('transaction_type', 'N/A')
                
                print(f"  {Colors.BOLD}{i}{Colors.ENDC}. {title}")
                print(f"     DISC: {disc} | Context: {context} | {transaction}")
                
            if len(scenarios) > 10:
                print(f"\n  ... and {len(scenarios) - 10} more scenarios")
                
            # Get user selection
            while True:
                try:
                    choice = input(f"\n{Colors.BOLD}Select scenario number (1-{min(10, len(scenarios))}): {Colors.ENDC}").strip()
                    idx = int(choice) - 1
                    if 0 <= idx < min(10, len(scenarios)):
                        self.current_scenario = scenarios[idx]
                        self.print_success(f"Selected: {self.current_scenario.get('title')}")
                        return True
                    else:
                        self.print_warning("Invalid selection")
                except ValueError:
                    self.print_warning("Enter a valid number")
                    
        except Exception as e:
            self.print_error(f"Error loading scenarios: {str(e)}")
            return False
            
    def create_session(self) -> bool:
        """Create a new training session."""
        self.print_header("STARTING SESSION")
        
        try:
            headers = {"Authorization": f"Bearer {self.auth_token}"}
            payload = {"scenario_id": self.current_scenario.get("id")}
            
            response = requests.post(
                f"{self.base_url}/api/sessions",
                json=payload,
                headers=headers,
                timeout=5
            )
            
            if response.status_code != 200:
                self.print_error(f"Failed to create session: {response.json()}")
                return False
                
            data = response.json()
            self.session_id = data.get("session_id")
            opening_msg = data.get("message", "")
            
            self.print_success(f"Session created (ID: {self.session_id})")
            self.print_info(f"Scenario: {self.current_scenario.get('title')}")
            
            # Display initial client greeting
            print(f"\n{Colors.BOLD}{Colors.OKGREEN}[CLIENT GREETING]{Colors.ENDC}")
            print(f"\n{Colors.OKBLUE}{opening_msg}{Colors.ENDC}\n")
            
            return True
        except Exception as e:
            self.print_error(f"Error creating session: {str(e)}")
            return False
            
    def chat_loop(self):
        """Interactive conversation loop."""
        self.print_header("CONVERSATION")
        self.print_info("Type your message and press Enter. Type 'quit' to exit, 'score' to see stats.")
        
        print(f"\n{Colors.GRAY}{'─'*70}{Colors.ENDC}\n")
        
        while True:
            try:
                # Get user input
                user_input = input(f"{Colors.BOLD}{Colors.OKGREEN}[YOU]:{Colors.ENDC} ").strip()
                
                if not user_input:
                    continue
                    
                if user_input.lower() == 'quit':
                    self.print_info("Thanks for using Convora CLI!")
                    sys.exit(0)
                    
                if user_input.lower() == 'score':
                    self.print_stats()
                    continue
                    
                # Send message to backend
                print()
                self._send_message(user_input)
                print(f"\n{Colors.GRAY}{'─'*70}{Colors.ENDC}\n")
                
            except KeyboardInterrupt:
                print("\n")
                self.print_info("Session interrupted by user")
                break
            except Exception as e:
                self.print_error(f"Error: {str(e)}")
                
    def _send_message(self, message: str):
        """Send message and display response."""
        try:
            headers = {"Authorization": f"Bearer {self.auth_token}"}
            payload = {"message": message}
            
            response = requests.post(
                f"{self.base_url}/api/sessions/{self.session_id}/messages",
                json=payload,
                headers=headers,
                timeout=10
            )
            
            if response.status_code != 200:
                self.print_error(f"Failed to send message: {response.json()}")
                return
                
            data = response.json()
            client_reply = data.get('reply', '')
            self.score = data.get('current_score', 0)
            objectives = data.get('objectives_completed', [])
            
            # Display client response
            print(f"{Colors.BOLD}{Colors.OKBLUE}[CLIENT]{Colors.ENDC}")
            print(f"\n{Colors.OKBLUE}{client_reply}{Colors.ENDC}\n")
            
            # Display achievements
            if objectives:
                objectives_str = ", ".join([f"{obj['objective']['label']}" for obj in objectives])
                self.print_success(f"Objectives completed: {objectives_str}")
                
            if self.score > 0:
                self.print_success(f"Session score: {self.score} points")
                
        except requests.exceptions.Timeout:
            self.print_warning("Request timed out (AI might be slower). Try again.")
        except Exception as e:
            self.print_error(f"Error sending message: {str(e)}")
            
    def print_stats(self):
        """Display current session stats."""
        print(f"\n{Colors.BOLD}{Colors.HEADER}SESSION STATS{Colors.ENDC}")
        print(f"  Session ID: {self.session_id}")
        print(f"  Scenario: {self.current_scenario.get('title') if self.current_scenario else 'N/A'}")
        print(f"  Current Score: {self.score}")
        print()
        
    def run(self):
        """Main entry point."""
        self.welcome()
        
        # Check backend
        print("Checking backend connection...")
        if not self.get_health():
            self.print_error("Backend is not running. Start it with: docker compose up")
            sys.exit(1)
        self.print_success("Backend is healthy")
        
        # Login
        while not self.login():
            retry = input(f"\n{Colors.BOLD}Try again? (y/n): {Colors.ENDC}").strip().lower()
            if retry != 'y':
                sys.exit(0)
                
        # Select scenario
        if not self.list_scenarios():
            sys.exit(1)
            
        # Create session
        if not self.create_session():
            sys.exit(1)
            
        # Start conversation
        self.chat_loop()


def main():
    """Entry point."""
    client = ConvoraClient()
    client.run()


if __name__ == "__main__":
    main()

"""Claude tool definitions for agentic conversation."""

# Tool definitions for Claude tool use
CONVERSATION_TOOLS = [
    {
        "name": "mark_objective_complete",
        "description": "Mark an objective as complete in the current training session. Call this when the ISA has achieved a specific training objective.",
        "input_schema": {
            "type": "object",
            "properties": {
                "objective_id": {
                    "type": "integer",
                    "description": "The ID of the objective that was achieved"
                },
                "notes": {
                    "type": "string",
                    "description": "Brief notes explaining why this objective was achieved (e.g., 'ISA asked about budget constraints')"
                }
            },
            "required": ["objective_id", "notes"]
        }
    },
    {
        "name": "add_bonus_points",
        "description": "Award bonus points for exceptional or unexpected positive interactions beyond the standard objectives.",
        "input_schema": {
            "type": "object",
            "properties": {
                "amount": {
                    "type": "integer",
                    "description": "Number of bonus points to award (1-20)"
                },
                "reason": {
                    "type": "string",
                    "description": "Reason for the bonus (e.g., 'Exceptional empathy for client situation')"
                }
            },
            "required": ["amount", "reason"]
        }
    },
    {
        "name": "disc_alignment_noted",
        "description": "Award points when the ISA demonstrates effective communication aligned with the client's DISC personality type.",
        "input_schema": {
            "type": "object",
            "properties": {
                "disc_type": {
                    "type": "string",
                    "enum": ["D", "I", "S", "C"],
                    "description": "The DISC type being demonstrated"
                },
                "example": {
                    "type": "string",
                    "description": "The specific communication technique used (e.g., 'Used direct, concise language for Dominant client')"
                }
            },
            "required": ["disc_type", "example"]
        }
    },
    {
        "name": "set_appointment",
        "description": "Mark that an appointment has been successfully set. This ends the training session.",
        "input_schema": {
            "type": "object",
            "properties": {
                "proposed_time": {
                    "type": "string",
                    "description": "The proposed appointment time/date discussed (e.g., 'Tuesday at 2 PM')"
                }
            },
            "required": ["proposed_time"]
        }
    },
    {
        "name": "end_conversation",
        "description": "End the conversation when the client disengages or the conversation becomes unproductive.",
        "input_schema": {
            "type": "object",
            "properties": {
                "reason": {
                    "type": "string",
                    "description": "Reason for ending the conversation (e.g., 'Client said they need to go', 'Call dropped')"
                }
            },
            "required": ["reason"]
        }
    }
]

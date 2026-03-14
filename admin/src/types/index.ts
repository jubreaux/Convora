// User and Authentication Types
export interface User {
  id: number;
  email: string;
  name: string;
  role: 'admin' | 'user';
  created_at: string;
}

export interface AuthResponse {
  access_token: string;
  token_type: string;
  user: User;
}

// Scenario Types
export interface Scenario {
  id: number;
  title: string;
  disc_type: 'D' | 'I' | 'S' | 'C';
  is_public: boolean;
  created_by_user_id?: number | null;
  created_at?: string;
  ai_system_prompt?: string;
}

export interface PersonalityTemplate {
  id: number;
  occupation: string;
  recreation?: string | null;
  family?: string | null;
  pets?: string | null;
  transaction_type: string;
  buy_criteria?: string | null;
  sell_criteria?: string | null;
  surface_motivation?: string | null;
  hidden_motivation?: string | null;
  timeframe?: string | null;
  red_flags?: string | null;
}

export interface TraitSet {
  id: number;
  trait_set_number: number;
  trait_1: string;
  trait_2: string;
  trait_3: string;
}

export interface ScenarioContext {
  id: number;
  name: string;
}

export interface Objective {
  id: number;
  label: string;
  description?: string | null;
  max_points: number;
}

export interface ObjectiveFormItem {
  label: string;
  description: string;
  max_points: number;
}

export interface ScenarioDetail extends Scenario {
  personality_template_id: number;
  personality_template?: PersonalityTemplate | null;
  trait_set_id: number;
  trait_set?: TraitSet | null;
  scenario_context_id: number;
  scenario_context?: ScenarioContext | null;
  objectives: Objective[];
}

export interface ScenarioCreateRequest {
  title: string;
  disc_type: 'D' | 'I' | 'S' | 'C';
  is_public: boolean;
  ai_system_prompt: string;
  personality_template_id?: number;
  trait_set_id?: number;
  scenario_context_id?: number;
  objectives?: ObjectiveFormItem[];
}

// Session Types
export interface Session {
  id: number;
  user_id: number;
  scenario_id: number;
  status: 'active' | 'completed' | 'abandoned';
  score: number;
  appointment_set: boolean;
  created_at: string;
  started_at: string;
  ended_at?: string | null;
}

export interface Message {
  id: number;
  session_id: number;
  role: 'user' | 'assistant' | 'tool_result';
  content: string;
  created_at: string;
}

export interface SessionDetail extends Session {
  messages: Message[];
}

export interface SessionHistory {
  id: number;
  scenario_id: number;
  scenario_title: string;
  status: string;
  score: number;
  started_at: string;
  ended_at?: string | null;
}

// Admin Dashboard Types
export interface UserStats {
  id: number;
  email: string;
  name: string;
  role: 'admin' | 'user';
  created_at: string;
  total_sessions: number;
  total_score: number;
  avg_session_score: number;
  last_session_date?: string | null;
  completed_objectives: number;
}

export interface UsersListResponse {
  total: number;
  users: UserStats[];
  offset: number;
  limit: number;
}

export interface DashboardStats {
  total_users: number;
  total_sessions: number;
  avg_score: number;
  disc_breakdown: {
    D: number;
    I: number;
    S: number;
    C: number;
  };
  sessions_per_day: Array<{
    date: string;
    count: number;
  }>;
  score_distribution: Array<{
    range: string;
    count: number;
  }>;
  top_scenarios: Array<{
    id: number;
    title: string;
    avg_score: number;
    session_count: number;
  }>;
  top_users: Array<{
    id: number;
    name: string;
    email: string;
    total_score: number;
  }>;
}

// API Response Wrappers
export interface ApiErrorResponse {
  detail: string | Array<{
    loc: string[];
    msg: string;
    type: string;
  }>;
}

export interface PaginationParams {
  offset?: number;
  limit?: number;
  search?: string;
}

// Session Review Types
export interface ScoreEvent {
  id: number;
  event_type: string;
  points: number;
  label?: string | null;
  reason?: string | null;
  created_at: string;
}

export interface SessionObjectiveDetail {
  id: number;
  objective: Objective;
  achieved: boolean;
  points_awarded: number;
  notes?: string | null;
  achieved_at?: string | null;
}

export interface SessionReview {
  id: number;
  scenario_id: number;
  scenario_title: string;
  status: string;
  final_score: number;
  appointment_set: boolean;
  disc_type: string;
  started_at: string;
  ended_at?: string | null;
  personality: PersonalityTemplate;
  trait_set: TraitSet;
  objectives: SessionObjectiveDetail[];
  messages: Message[];
  score_events: ScoreEvent[];
}

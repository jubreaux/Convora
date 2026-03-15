import axios, { AxiosInstance } from 'axios';
import {
  AuthResponse,
  User,
  Scenario,
  ScenarioDetail,
  ScenarioCreateRequest,
  PersonalityTemplate,
  TraitSet,
  ScenarioContext,
  UsersListResponse,
  DashboardStats,
  UserStats,
  PaginationParams,
  SessionHistory,
  SessionReview,
} from '../types';

const API_BASE_URL = process.env.REACT_APP_API_BASE_URL || 'https://api.convora.customertest.digitalbullet.net';

class ApiClient {
  private api: AxiosInstance;

  constructor() {
    this.api = axios.create({
      baseURL: API_BASE_URL,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Add token to every request
    this.api.interceptors.request.use((config) => {
      const token = this.getToken();
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
      return config;
    });

    // Handle errors globally (but don't auto-redirect - let components handle it)
    this.api.interceptors.response.use(
      (response) => response,
      (error) => {
        // Don't auto-redirect on 401 - let the component handle the error
        // so users can see what went wrong instead of getting a hard reset
        return Promise.reject(error);
      }
    );
  }

  // ========== Token Management ==========
  setToken(token: string): void {
    localStorage.setItem('token', token);
  }

  getToken(): string | null {
    return localStorage.getItem('token');
  }

  clearToken(): void {
    localStorage.removeItem('token');
  }

  // ========== Authentication ==========
  async login(email: string, password: string): Promise<AuthResponse> {
    const response = await this.api.post<AuthResponse>('/api/auth/login', {
      email,
      password,
    });
    if (response.data.access_token) {
      this.setToken(response.data.access_token);
    }
    return response.data;
  }

  async logout(): Promise<void> {
    this.clearToken();
  }

  async register(email: string, password: string, name: string): Promise<AuthResponse> {
    const response = await this.api.post<AuthResponse>('/api/auth/register', {
      email,
      password,
      name,
    });
    // Note: Don't auto-login for registration from admin panel
    return response.data;
  }

  async getCurrentUser(): Promise<User> {
    const response = await this.api.get<User>('/api/auth/me');
    return response.data;
  }

  // ========== User Management (Admin) ==========
  async getUsers(params: PaginationParams = {}): Promise<UsersListResponse> {
    const { offset = 0, limit = 20, search = '' } = params;
    const response = await this.api.get<UsersListResponse>('/api/admin/users', {
      params: {
        offset,
        limit,
        search,
      },
    });
    return response.data;
  }

  async getUserDetail(userId: number): Promise<UserStats> {
    const response = await this.api.get<UserStats>(`/api/admin/users/${userId}`);
    return response.data;
  }

  async getUserSessions(userId: number): Promise<SessionHistory[]> {
    const response = await this.api.get<SessionHistory[]>(`/api/sessions/users/${userId}/history`);
    return response.data;
  }

  async getSessionReview(sessionId: number): Promise<SessionReview> {
    const response = await this.api.get<SessionReview>(`/api/sessions/${sessionId}/review`);
    return response.data;
  }

  async updateUser(userId: number, userData: Partial<{name: string; email: string; password: string; role: string}>): Promise<User> {
    const response = await this.api.patch<User>(`/api/admin/users/${userId}`, userData);
    return response.data;
  }

  async deleteUser(userId: number): Promise<{ message: string; user_id: number; deleted_at: string }> {
    const response = await this.api.delete<{ message: string; user_id: number; deleted_at: string }>(`/api/admin/users/${userId}`);
    return response.data;
  }

  // ========== Scenario Management ==========
  async listScenarios(): Promise<Scenario[]> {
    const response = await this.api.get<Scenario[]>('/api/scenarios');
    return response.data;
  }

  async getScenario(scenarioId: number): Promise<ScenarioDetail> {
    const response = await this.api.get<ScenarioDetail>(`/api/scenarios/${scenarioId}`);
    return response.data;
  }

  async createScenario(scenario: ScenarioCreateRequest): Promise<Scenario> {
    const response = await this.api.post<Scenario>('/api/scenarios', scenario);
    return response.data;
  }

  async updateScenario(scenarioId: number, scenario: Partial<ScenarioCreateRequest>): Promise<ScenarioDetail> {
    const response = await this.api.put<ScenarioDetail>(`/api/scenarios/${scenarioId}`, scenario);
    return response.data;
  }

  async deleteScenario(scenarioId: number): Promise<void> {
    await this.api.delete(`/api/scenarios/${scenarioId}`);
  }

  // ========== Admin Scenario Management ==========
  async listAdminScenarios(params: {
    search?: string;
    visibility?: string;
    offset?: number;
    limit?: number;
    sort_by?: string;
    sort_order?: string;
  } = {}): Promise<any> {
    const {
      search = '',
      visibility,
      offset = 0,
      limit = 50,
      sort_by = 'created_at',
      sort_order = 'desc',
    } = params;

    const queryParams = new URLSearchParams({
      search,
      offset: offset.toString(),
      limit: limit.toString(),
      sort_by,
      sort_order,
    });

    if (visibility) {
      queryParams.append('visibility', visibility);
    }

    const response = await this.api.get(`/api/admin/scenarios?${queryParams.toString()}`);
    return response.data;
  }

  async updateScenarioVisibility(
    scenarioId: number,
    visibility: string,
    orgId?: number
  ): Promise<{ id: number; message: string; visibility: string }> {
    const queryParams = new URLSearchParams({ visibility });
    if (orgId) {
      queryParams.append('org_id', orgId.toString());
    }
    const response = await this.api.put(
      `/api/admin/scenarios/${scenarioId}/visibility?${queryParams.toString()}`
    );
    return response.data;
  }

  async getPersonalityTemplates(): Promise<PersonalityTemplate[]> {
    const response = await this.api.get<PersonalityTemplate[]>('/api/admin/personality-templates');
    return response.data;
  }

  async getTraitSets(): Promise<TraitSet[]> {
    const response = await this.api.get<TraitSet[]>('/api/admin/trait-sets');
    return response.data;
  }

  async getScenarioContexts(): Promise<ScenarioContext[]> {
    const response = await this.api.get<ScenarioContext[]>('/api/admin/scenario-contexts');
    return response.data;
  }

  // ========== Dashboard & Analytics ==========
  async getDashboardStats(): Promise<DashboardStats> {
    const response = await this.api.get<DashboardStats>('/api/admin/stats');
    return response.data;
  }

  // ========== Health Check ==========
  async healthCheck(): Promise<{ status: string; version: string }> {
    const response = await this.api.get<{ status: string; version: string }>('/health');
    return response.data;
  }
}

const apiClient = new ApiClient();
export default apiClient;

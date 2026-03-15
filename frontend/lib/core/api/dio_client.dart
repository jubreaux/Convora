import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:convora/core/config/app_config.dart';
import 'convora_api.dart';

class DioClient {
  late Dio dio;
  final FlutterSecureStorage secureStorage;
  static const String _tokenKey = 'auth_token';

  DioClient({required this.secureStorage, required String initialBaseUrl}) {
    _initDio(initialBaseUrl);
  }

  void _initDio(String baseUrl) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: Duration(seconds: AppConfig.connectTimeoutSeconds),
        receiveTimeout: Duration(seconds: AppConfig.receiveTimeoutSeconds),
        contentType: 'application/json',
      ),
    );

    // Add interceptor for JWT token
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  /// Update the base URL in-place (no new DioClient needed).
  void updateBaseUrl(String url) {
    dio.options.baseUrl = url;
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await secureStorage.read(key: _tokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    handler.next(err);
  }

  Future<void> saveToken(String token) async {
    await secureStorage.write(key: _tokenKey, value: token);
  }

  Future<void> deleteToken() async {
    await secureStorage.delete(key: _tokenKey);
  }

  Future<String?> getToken() async {
    return await secureStorage.read(key: _tokenKey);
  }

  void close() {
    dio.close();
  }
}

class ConvoraApiClient {
  final DioClient dioClient;

  ConvoraApiClient({required this.dioClient});

  /// Returns the stored JWT token (used to check if a session exists).
  Future<String?> getStoredToken() => dioClient.getToken();

  // ===== Auth =====
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String name,
    required String accountType,
    String? companyName,
  }) async {
    final response = await dioClient.dio.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'name': name,
        'account_type': accountType,
        if (companyName != null) 'company_name': companyName,
      },
    );
    final authResponse = AuthResponse.fromJson(response.data);
    await dioClient.saveToken(authResponse.accessToken);
    return authResponse;
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await dioClient.dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final authResponse = AuthResponse.fromJson(response.data);
    await dioClient.saveToken(authResponse.accessToken);
    return authResponse;
  }

  Future<void> logout() async {
    await dioClient.deleteToken();
  }

  Future<User> getCurrentUser() async {
    final response = await dioClient.dio.get('/auth/me');
    return User.fromJson(response.data);
  }

  Future<User> updateProfile({
    String? name,
    String? email,
    bool updateVoice = false,
    String? voicePreference,
  }) async {
    final response = await dioClient.dio.put(
      '/auth/me',
      data: {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (updateVoice) 'preferred_voice': voicePreference,
      },
    );
    return User.fromJson(response.data);
  }

  // ===== Scenarios =====
  Future<List<ScenarioList>> getScenarios() async {
    final response = await dioClient.dio.get('/scenarios');
    return (response.data as List)
        .map((s) => ScenarioList.fromJson(s))
        .toList();
  }

  Future<ScenarioList> getRandomScenario() async {
    final response = await dioClient.dio.get('/scenarios/random');
    return ScenarioList.fromJson(response.data);
  }

  Future<ScenarioDetail> getScenarioDetail(int scenarioId) async {
    final response = await dioClient.dio.get('/scenarios/$scenarioId');
    return ScenarioDetail.fromJson(response.data);
  }

  /// Create a new scenario
  Future<ScenarioList> createScenario({
    required String title,
    required String discType,
    required String aiSystemPrompt,
    required String visibility,
    int? personalityTemplateId,
    int? traitSetId,
    int? scenarioContextId,
    List<Map<String, dynamic>>? objectives,
  }) async {
    final response = await dioClient.dio.post(
      '/scenarios',
      data: {
        'title': title,
        'disc_type': discType,
        'ai_system_prompt': aiSystemPrompt,
        'visibility': visibility,
        'personality_template_id': personalityTemplateId,
        'trait_set_id': traitSetId,
        'scenario_context_id': scenarioContextId,
        'objectives': objectives ?? [],
      },
    );
    return ScenarioList.fromJson(response.data);
  }

  /// Update an existing scenario
  Future<ScenarioList> updateScenario({
    required int scenarioId,
    required String title,
    required String discType,
    required String aiSystemPrompt,
    required String visibility,
    int? personalityTemplateId,
    int? traitSetId,
    int? scenarioContextId,
    List<Map<String, dynamic>>? objectives,
  }) async {
    final response = await dioClient.dio.put(
      '/scenarios/$scenarioId',
      data: {
        'title': title,
        'disc_type': discType,
        'ai_system_prompt': aiSystemPrompt,
        'visibility': visibility,
        'personality_template_id': personalityTemplateId,
        'trait_set_id': traitSetId,
        'scenario_context_id': scenarioContextId,
        'objectives': objectives ?? [],
      },
    );
    return ScenarioList.fromJson(response.data);
  }

  /// Delete a scenario
  Future<void> deleteScenario(int scenarioId) async {
    await dioClient.dio.delete('/scenarios/$scenarioId');
  }

  /// Get all personality templates (for scenario creation/editing forms)
  Future<List<PersonalityTemplate>> getPersonalityTemplates() async {
    final response = await dioClient.dio.get('/metadata/personality-templates');
    return (response.data as List)
        .map((t) => PersonalityTemplate.fromJson(t))
        .toList();
  }

  /// Get all trait sets (for scenario creation/editing forms)
  Future<List<TraitSet>> getTraitSets() async {
    final response = await dioClient.dio.get('/metadata/trait-sets');
    return (response.data as List).map((t) => TraitSet.fromJson(t)).toList();
  }

  /// Get all scenario contexts (for scenario creation/editing forms)
  Future<List<ScenarioContext>> getScenarioContexts() async {
    final response = await dioClient.dio.get('/metadata/scenario-contexts');
    return (response.data as List)
        .map((c) => ScenarioContext.fromJson(c))
        .toList();
  }

  // ===== Sessions =====
  Future<Map<String, dynamic>> createSession(int scenarioId) async {
    final response = await dioClient.dio.post(
      '/sessions',
      data: {'scenario_id': scenarioId},
    );
    return response.data;
  }

  Future<SessionMessageResponse> sendMessage({
    required int sessionId,
    required String message,
    bool voice = false,
  }) async {
    final response = await dioClient.dio.post(
      '/sessions/$sessionId/messages',
      data: {'message': message, 'voice': voice},
    );
    return SessionMessageResponse.fromJson(response.data);
  }

  Future<SessionEndResponse> endSession(int sessionId) async {
    final response = await dioClient.dio.post('/sessions/$sessionId/end');
    return SessionEndResponse.fromJson(response.data);
  }

  Future<String> synthesizeText(String text) async {
    final response = await dioClient.dio.post(
      '/tts/synthesize',
      data: {'text': text},
    );
    return response.data['audio_base64'] as String;
  }

  Future<List<SessionHistory>> getUserHistory() async {
    final response = await dioClient.dio.get('/sessions/users/history');
    return (response.data as List)
        .map((s) => SessionHistory.fromJson(s))
        .toList();
  }

  Future<SessionReviewResponse> getSessionReview(int sessionId) async {
    final response = await dioClient.dio.get('/sessions/$sessionId/review');
    return SessionReviewResponse.fromJson(response.data);
  }

  Future<UserStats> getUserStats() async {
    final response = await dioClient.dio.get('/sessions/stats/summary');
    return UserStats.fromJson(response.data);
  }

  /// Submit feedback (vote + comment) for a session
  Future<void> submitFeedback({
    required int sessionId,
    required int vote, // -1, 0, or 1
    String? comment,
  }) async {
    await dioClient.dio.post(
      '/sessions/$sessionId/feedback',
      data: {'vote': vote, 'comment': comment},
    );
  }

  // ===== Organization =====
  Future<List<OrgMember>> getOrgMembers() async {
    final response = await dioClient.dio.get('/auth/org/members');
    return (response.data as List).map((m) => OrgMember.fromJson(m)).toList();
  }

  Future<OrgMember> inviteOrgMember({
    required String email,
    required String name,
    required String tempPassword,
    String orgRole = 'member',
  }) async {
    final response = await dioClient.dio.post(
      '/auth/org/members',
      data: {
        'email': email,
        'name': name,
        'temp_password': tempPassword,
        'org_role': orgRole,
      },
    );
    return OrgMember.fromJson(response.data);
  }

  Future<void> deactivateOrgMember(int userId) async {
    await dioClient.dio.delete('/auth/org/members/$userId');
  }

  Future<List<OrgMemberStats>> getOrgAnalytics() async {
    final response = await dioClient.dio.get('/auth/org/analytics');
    return (response.data as List)
        .map((m) => OrgMemberStats.fromJson(m))
        .toList();
  }

  // ===== Team Management Methods =====

  Future<List<TeamStats>> getOrgTeams() async {
    final response = await dioClient.dio.get('/auth/org/teams');
    return (response.data as List).map((t) => TeamStats.fromJson(t)).toList();
  }

  Future<TeamStats> createOrgTeam(String name, String? description) async {
    final response = await dioClient.dio.post(
      '/auth/org/teams',
      data: {'name': name, 'description': description},
    );
    return TeamStats.fromJson(response.data);
  }

  Future<TeamStats> updateOrgTeam(
    int teamId,
    String name,
    String? description,
  ) async {
    final response = await dioClient.dio.put(
      '/auth/org/teams/$teamId',
      data: {'name': name, 'description': description},
    );
    return TeamStats.fromJson(response.data);
  }

  Future<void> deleteOrgTeam(int teamId) async {
    await dioClient.dio.delete('/auth/org/teams/$teamId');
  }

  Future<List<TeamMemberDetail>> getTeamMembers(int teamId) async {
    final response = await dioClient.dio.get('/auth/org/teams/$teamId/members');
    return (response.data as List)
        .map((m) => TeamMemberDetail.fromJson(m))
        .toList();
  }

  Future<void> addTeamMember(int teamId, int userId, bool isTeamLead) async {
    await dioClient.dio.post(
      '/auth/org/teams/$teamId/members',
      data: {'user_id': userId, 'is_team_lead': isTeamLead},
    );
  }

  Future<void> removeTeamMember(int teamId, int userId) async {
    await dioClient.dio.delete('/auth/org/teams/$teamId/members/$userId');
  }

  Future<List<MemberSessionSummary>> getMemberSessions(int userId) async {
    final response = await dioClient.dio.get(
      '/auth/org/members/$userId/sessions',
    );
    return (response.data as List)
        .map((s) => MemberSessionSummary.fromJson(s))
        .toList();
  }
}

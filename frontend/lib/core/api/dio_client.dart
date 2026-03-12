import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'convora_api.dart';

class DioClient {
  late Dio dio;
  final FlutterSecureStorage secureStorage;
  static const String _baseUrl = 'http://10.0.2.2:8000/api';
  static const String _tokenKey = 'auth_token';

  DioClient({required this.secureStorage}) {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),  // Increased for voice round-trips (STT + LLM + TTS)
        receiveTimeout: const Duration(seconds: 30),  // Increased for TTS synthesis
        contentType: 'application/json',
      ),
    );

    // Add interceptor for JWT token
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await secureStorage.read(key: _tokenKey);
    print('[DIO] Request to: ${options.path}, Token: ${token != null ? "✓ present" : "✗ missing"}');
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

  // ===== Auth =====
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await dioClient.dio.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'name': name,
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
      data: {
        'email': email,
        'password': password,
      },
    );
    final authResponse = AuthResponse.fromJson(response.data);
    await dioClient.saveToken(authResponse.accessToken);
    return authResponse;
  }

  Future<void> logout() async {
    await dioClient.deleteToken();
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
    bool voice = false,  // If true, request TTS audio synthesis
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

  Future<List<SessionHistory>> getUserHistory() async {
    final response = await dioClient.dio.get('/sessions/users/history');
    return (response.data as List)
        .map((s) => SessionHistory.fromJson(s))
        .toList();
  }
}

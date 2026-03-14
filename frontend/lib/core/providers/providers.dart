import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:convora/core/api/convora_api.dart';
import 'dart:convert';
import 'package:just_audio/just_audio.dart';

// ===== Dio Client Provider =====
final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(secureStorage: const FlutterSecureStorage());
});

// ===== API Client Provider =====
final apiClientProvider = Provider<ConvoraApiClient>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ConvoraApiClient(dioClient: dioClient);
});

// ===== Auth State =====
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

// ===== Auth State Notifier =====
class AuthNotifier extends StateNotifier<AuthState> {
  final ConvoraApiClient apiClient;

  AuthNotifier(this.apiClient) : super(AuthState());

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiClient.register(
        email: email,
        password: password,
        name: name,
      );
      state = state.copyWith(
        user: response.user,
        isAuthenticated: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiClient.login(
        email: email,
        password: password,
      );
      state = state.copyWith(
        user: response.user,
        isAuthenticated: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    await apiClient.logout();
    state = AuthState();
  }
}

// ===== Auth Provider =====
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});

// ===== Scenarios Provider (waits for auth) =====
final scenariosProvider = FutureProvider<List<ScenarioList>>((ref) async {
  // Wait for auth to be ready before fetching scenarios
  final authState = ref.watch(authProvider);
  
  if (!authState.isAuthenticated) {
    throw Exception('Not authenticated');
  }
  
  // Add a small delay to ensure token is persisted
  await Future.delayed(const Duration(milliseconds: 100));
  
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getScenarios();
});

// ===== Random Scenario Provider (waits for auth) =====
final randomScenarioProvider = FutureProvider<ScenarioList>((ref) async {
  // Wait for auth to be ready before fetching
  final authState = ref.watch(authProvider);
  
  if (!authState.isAuthenticated) {
    throw Exception('Not authenticated');
  }
  
  // Add a small delay to ensure token is persisted
  await Future.delayed(const Duration(milliseconds: 100));
  
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getRandomScenario();
});

// ===== Session History Provider (waits for auth) =====
final sessionHistoryProvider =
    FutureProvider<List<SessionHistory>>((ref) async {
  // Wait for auth to be ready before fetching
  final authState = ref.watch(authProvider);
  
  if (!authState.isAuthenticated) {
    throw Exception('Not authenticated');
  }
  
  // Add a small delay to ensure token is persisted
  await Future.delayed(const Duration(milliseconds: 100));
  
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getUserHistory();
});

// ===== Active Session State =====
class ActiveSessionState {
  final int? sessionId;
  final int? scenarioId;
  final String scenarioTitle;  // NEW: Store the scenario title for display
  final List<SessionMessage> messages;
  final int currentScore;
  final bool appointmentSet;
  final List<SessionObjective> objectivesCompleted;
  final SessionEndResponse? sessionEndData;
  final bool isEnded;
  final bool isLoading;
  final String? error;
  final bool isRecording;        // Mic is actively recording
  final bool isSpeaking;         // Audio is playing back
  final String liveTranscript;   // Partial transcript while recording

  const ActiveSessionState({
    this.sessionId,
    this.scenarioId,
    this.scenarioTitle = '',  // NEW: Default empty
    this.messages = const [],
    this.currentScore = 0,
    this.appointmentSet = false,
    this.objectivesCompleted = const [],
    this.sessionEndData,
    this.isEnded = false,
    this.isLoading = false,
    this.error,
    this.isRecording = false,
    this.isSpeaking = false,
    this.liveTranscript = '',
  });

  ActiveSessionState copyWith({
    int? sessionId,
    int? scenarioId,
    String? scenarioTitle,  // NEW
    List<SessionMessage>? messages,
    int? currentScore,
    bool? appointmentSet,
    List<SessionObjective>? objectivesCompleted,
    SessionEndResponse? sessionEndData,
    bool? isEnded,
    bool? isLoading,
    String? error,
    bool? isRecording,
    bool? isSpeaking,
    String? liveTranscript,
  }) {
    return ActiveSessionState(
      sessionId: sessionId ?? this.sessionId,
      scenarioId: scenarioId ?? this.scenarioId,
      scenarioTitle: scenarioTitle ?? this.scenarioTitle,  // NEW
      messages: messages ?? this.messages,
      currentScore: currentScore ?? this.currentScore,
      appointmentSet: appointmentSet ?? this.appointmentSet,
      objectivesCompleted: objectivesCompleted ?? this.objectivesCompleted,
      sessionEndData: sessionEndData ?? this.sessionEndData,
      isEnded: isEnded ?? this.isEnded,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isRecording: isRecording ?? this.isRecording,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      liveTranscript: liveTranscript ?? this.liveTranscript,
    );
  }
}

// ===== Active Session Notifier =====
class ActiveSessionNotifier extends StateNotifier<ActiveSessionState> {
  final ConvoraApiClient apiClient;
  late final AudioPlayer _audioPlayer;

  ActiveSessionNotifier(this.apiClient) : super(ActiveSessionState()) {
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> startSession(int scenarioId, String scenarioTitle) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiClient.createSession(scenarioId);
      final sessionId = response['session_id'] as int;
      final message = response['message'] as String;

      state = state.copyWith(
        sessionId: sessionId,
        scenarioId: scenarioId,
        scenarioTitle: scenarioTitle,  // NEW: Store the title
        messages: [
          SessionMessage(
            id: 0,
            role: 'assistant',
            content: message,
            createdAt: DateTime.now(),
          )
        ],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> endSession() async {
    if (state.sessionId == null) throw StateError('No active session to end');
    if (state.isEnded) return;

    state = state.copyWith(isLoading: true, error: null);

    final endData = await apiClient.endSession(state.sessionId!);
    // ^ throws on non-2xx — let it propagate; no catch/fallback

    state = state.copyWith(
      sessionEndData: endData,
      isEnded: true,
      isLoading: false,
    );
  }

  Future<void> startListening() async {
    if (state.sessionId == null) {
      throw StateError('No active session');
    }
    // On-device speech recognition will update liveTranscript via updateTranscript
    state = state.copyWith(isRecording: true, liveTranscript: '');
  }

  void updateTranscript(String transcript) {
    state = state.copyWith(liveTranscript: transcript);
  }

  void stopRecording() {
    state = state.copyWith(isRecording: false);
  }

  Future<void> stopAndSend() async {
    if (state.liveTranscript.trim().isEmpty) {
      throw Exception('No transcript; silence or recognition failed');
    }

    state = state.copyWith(isRecording: false);
    await sendMessage(state.liveTranscript, voice: true);
  }

  Future<void> sendMessage(String message, {bool voice = false}) async {
    if (state.sessionId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Add user message locally
      final userMsg = SessionMessage(
        id: state.messages.length,
        role: 'user',
        content: message,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, userMsg],
        liveTranscript: '',  // Clear transcript after sending
      );

      // Get response from server
      final response = await apiClient.sendMessage(
        sessionId: state.sessionId!,
        message: message,
        voice: voice,
      );

      // Add assistant response
      final assistantMsg = SessionMessage(
        id: state.messages.length,
        role: 'assistant',
        content: response.reply,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        currentScore: response.currentScore,
        objectivesCompleted: response.objectivesCompleted,
        appointmentSet: response.appointmentSet,
        isLoading: false,
      );

      // Play audio if provided (voice mode)
      if (response.audioBase64 != null && response.audioBase64!.isNotEmpty) {
        await _playAudio(response.audioBase64!);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _playAudio(String base64Mp3) async {
    state = state.copyWith(isSpeaking: true);
    try {
      // Decode base64 to bytes
      final audioBytes = base64.decode(base64Mp3);
      
      // Create a temporary source from the bytes
      final source = AudioSource.uri(
        Uri.dataFromBytes(audioBytes, mimeType: 'audio/mpeg'),
      );
      
      // Load and play the audio
      await _audioPlayer.setAudioSource(source);
      await _audioPlayer.play();
      
      // Wait for playback to finish by monitoring player state
      bool isPlaying = true;
      _audioPlayer.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          isPlaying = false;
        }
      });
      
      // Wait a bit for playback to complete (with a safety timeout)
      for (int i = 0; i < 300; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        final currentState = _audioPlayer.playerState;
        if (currentState.processingState == ProcessingState.completed) {
          break;
        }
      }
    } catch (e) {
      // Log error but don't crash - voice is optional
      print('Audio playback error: $e');
    } finally {
      state = state.copyWith(isSpeaking: false);
    }
  }

  void reset() {
    _audioPlayer.stop();
    state = const ActiveSessionState();
  }
}

// ===== Active Session Provider =====
final activeSessionProvider =
    StateNotifierProvider<ActiveSessionNotifier, ActiveSessionState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ActiveSessionNotifier(apiClient);
});

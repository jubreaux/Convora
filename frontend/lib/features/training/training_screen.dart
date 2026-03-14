import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:convora/core/providers/providers.dart';
import 'package:permission_handler/permission_handler.dart';

class TrainingSessionScreen extends ConsumerStatefulWidget {
  const TrainingSessionScreen({super.key});

  @override
  ConsumerState<TrainingSessionScreen> createState() =>
      _TrainingSessionScreenState();
}

class _TrainingSessionScreenState
    extends ConsumerState<TrainingSessionScreen> {
  late TextEditingController _messageController;
  late stt.SpeechToText _speechToText;
  late ScrollController _scrollController;
  bool _speechInitialized = false;
  bool _hasText = false;
  bool _voiceMode = false;
  bool _isStartingListening = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    _speechToText = stt.SpeechToText();
    _scrollController = ScrollController();
    _initSpeech();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speechToText.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speechToText.initialize(
        onError: (error) => debugPrint('Speech error: $error'),
        onStatus: (status) => debugPrint('Speech status: $status'),
      );
      if (available) {
        setState(() => _speechInitialized = true);
      }
    } catch (e) {
      debugPrint('Error initializing speech: $e');
    }
  }

  Future<void> _startListening() async {
    // Guard against concurrent calls (e.g. double-tap or rapid auto-resume)
    if (_isStartingListening) return;
    _isStartingListening = true;

    try {
      // Re-initialize on every call — Android SpeechRecognizer needs this
      // after a session ends (finalResult) to avoid silent failures.
      await _initSpeech();
      if (!_speechInitialized) return;

      // Request mic permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission required'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Enter voice conversation mode
      _voiceMode = true;

      // Call notifier to set isRecording=true
      await ref.read(activeSessionProvider.notifier).startListening();

      _speechToText.listen(
        onResult: (result) {
          // Update live transcript as user speaks
          ref.read(activeSessionProvider.notifier).updateTranscript(result.recognizedWords);

          // Auto-send when speech recognition is final (complete)
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _speechToText.stop();
            _stopListeningAndSend();
          }
        },
        onSoundLevelChange: null,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        localeId: 'en_US',
        listenOptions: stt.SpeechListenOptions(cancelOnError: true),
      );
    } finally {
      _isStartingListening = false;
    }
  }

  Future<void> _stopListeningAndSend() async {
    await _speechToText.stop();
    final transcript = ref.read(activeSessionProvider).liveTranscript.trim();

    if (transcript.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No speech detected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      ref.read(activeSessionProvider.notifier).stopRecording();
      return;
    }

    // Clear recording state BEFORE the async send so it doesn't race
    // with the auto-resume microtask that fires after TTS finishes.
    ref.read(activeSessionProvider.notifier).stopRecording();

    // Send with voice=true to trigger TTS
    await ref
        .read(activeSessionProvider.notifier)
        .sendMessage(transcript, voice: true);
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    setState(() => _hasText = false);

    // Send text with voice=false (no TTS response audio)
    await ref
        .read(activeSessionProvider.notifier)
        .sendMessage(message, voice: false);
  }

  Future<void> _endSession() async {
    final session = ref.read(activeSessionProvider);
    if (session.sessionId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active session. Please start a training session first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    try {
      await ref.read(activeSessionProvider.notifier).endSession();
      // Navigation is handled by the ref.listen block in build().
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(activeSessionProvider);
    final isProcessing = sessionState.isLoading || sessionState.isSpeaking;

    // Watch for error and display snackbar
    ref.listen(activeSessionProvider, (previous, next) {
      if (next.error != null && (previous?.error != next.error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }

      // Stop STT immediately when AI starts speaking (prevent echo/feedback)
      if (next.isSpeaking && !(previous?.isSpeaking ?? false)) {
        if (_speechToText.isListening) {
          _speechToText.stop();
          ref.read(activeSessionProvider.notifier).stopRecording();
        }
      }

      // Auto-restart listening after TTS finishes (voice conversation loop)
      // Delay 600ms to let the Android SpeechRecognizer fully release before
      // re-opening (prevents silent failure on 2nd+ listen attempt).
      if (_voiceMode &&
          (previous?.isSpeaking ?? false) &&
          !next.isSpeaking &&
          !next.isEnded &&
          !next.isLoading) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && _voiceMode) _startListening();
        });
      }

      // Clear voice mode when session ends
      if (next.isEnded && !(previous?.isEnded ?? false)) {
        _voiceMode = false;
        // Auto-navigate to feedback when session ends
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) context.go('/feedback');
        });
      }
    });

    // Auto-scroll to newest message (position 0 = bottom in a reversed list).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && sessionState.messages.isNotEmpty) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(sessionState.scenarioTitle ?? 'Training Session'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Score',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.teal,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    '${sessionState.currentScore}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: _endSession,
                child: const Text('End Session'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              itemCount: sessionState.messages.length,
              itemBuilder: (context, index) {
                final message =
                    sessionState.messages[sessionState.messages.length - 1 - index];
                final isUser = message.role == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Appointment banner
          if (sessionState.appointmentSet)
            Container(
              color: Colors.amber.shade50,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.orange),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Appointment scheduled - discuss details in this session!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (sessionState.objectivesCompleted.isNotEmpty)
            Container(
              color: Colors.green.shade50,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Objectives Completed:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...sessionState.objectivesCompleted
                      .map((obj) => Text('✓ ${obj.objective.label}'))
                ],
              ),
            ),
          // Show live transcript during recording
          if (sessionState.isRecording)
            Container(
              color: Colors.blue.shade50,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.red),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sessionState.liveTranscript.isEmpty
                          ? 'Listening...'
                          : sessionState.liveTranscript,
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Input area: text field + mic button + send button
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Mic button
                FloatingActionButton(
                  heroTag: 'micButton',
                  mini: true,
                  backgroundColor: sessionState.isRecording
                      ? Colors.red
                      : (isProcessing ? Colors.grey : Colors.blueAccent),
                  onPressed: isProcessing
                      ? null
                      : (sessionState.isRecording
                          ? _stopListeningAndSend
                          : _startListening),
                  child: sessionState.isRecording
                      ? const Icon(Icons.mic, color: Colors.white)
                      : (isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.mic_none, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                // Text input field (disabled while recording or speaking)
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !sessionState.isRecording && !sessionState.isSpeaking,
                    decoration: InputDecoration(
                      hintText: sessionState.isRecording
                          ? 'Recording...'
                          : (sessionState.isSpeaking
                              ? 'Playing...'
                              : 'Type your response...'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) =>
                        isProcessing ? null : _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                FloatingActionButton(
                  heroTag: 'sendButton',
                  onPressed: isProcessing || sessionState.isRecording || !_hasText
                      ? null
                      : _sendMessage,
                  mini: true,
                  child: isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

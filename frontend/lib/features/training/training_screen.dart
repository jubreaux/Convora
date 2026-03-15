import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:convora/core/providers/providers.dart';
import 'package:convora/core/models/models.dart';
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
  int? _playingMessageId;
  bool _objectivesExpanded = false;  // Track objectives panel expansion

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
        final router = GoRouter.of(context);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) router.go('/feedback');
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F7A7E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          sessionState.scenarioTitle.isEmpty
              ? 'Training Session'
              : sessionState.scenarioTitle,
          style: const TextStyle(fontSize: 14, color: Colors.white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Score',
                    style: TextStyle(
                        fontSize: 9, color: Colors.white70, height: 1.0),
                  ),
                  Text(
                    '${sessionState.currentScore}/${sessionState.maxScore}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton(
            iconColor: Colors.white,
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
          // Objectives Panel - Show ONLY on load (before any messages appear)
          if (sessionState.messages.isEmpty)
            _buildObjectivesPanel(sessionState),

          // Messages list
          Expanded(
            child: sessionState.messages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation(Color(0xFF1F7A7E)),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: sessionState.messages.length,
                    itemBuilder: (context, index) {
                      final message = sessionState.messages[
                          sessionState.messages.length - 1 - index];
                      return _buildMessageBubble(
                          context, message, sessionState);
                    },
                  ),
          ),

          // Appointment banner
          if (sessionState.appointmentSet)
            Container(
              color: Colors.amber.shade50,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                children: [
                  Icon(Icons.schedule, color: Colors.orange, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Appointment scheduled — discuss details in this session!',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          // Live transcript during recording
          if (sessionState.isRecording &&
              sessionState.liveTranscript.isNotEmpty)
            Container(
              color: Colors.red.shade50,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sessionState.liveTranscript,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Status pill (Listening / Thinking / Speaking)
          _buildStatusPill(sessionState),

          // Input bar
          _buildInputBar(context, sessionState),
        ],
      ),
    );
  }

  // ---- On-demand TTS playback ----
  void _playMessage(SessionMessage message) async {
    if (_playingMessageId != null) return;
    setState(() => _playingMessageId = message.id);
    try {
      await ref
          .read(activeSessionProvider.notifier)
          .playMessageAudio(message.content);
    } finally {
      if (mounted) setState(() => _playingMessageId = null);
    }
  }

  // ---- Message bubble builder ----
  Widget _buildMessageBubble(
    BuildContext context,
    SessionMessage message,
    ActiveSessionState sessionState,
  ) {
    final isUser = message.role == 'user';
    final isBlocked = sessionState.isLoading ||
        sessionState.isSpeaking ||
        sessionState.isRecording;
    final isThisPlaying = _playingMessageId == message.id;

    if (isUser) {
      return Padding(
        padding:
            const EdgeInsets.only(left: 56, right: 12, top: 3, bottom: 3),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1F7A7E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Text(
              message.content,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, height: 1.4),
            ),
          ),
        ),
      );
    }

    // AI message
    return Padding(
      padding:
          const EdgeInsets.only(left: 8, right: 56, top: 3, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI avatar circle
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1F7A7E),
            ),
            child: const Center(
              child: Text(
                'AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Bubble content
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Play button row
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: (isBlocked || _playingMessageId != null)
                          ? null
                          : () => _playMessage(message),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: isThisPlaying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                      Color(0xFF1F7A7E)),
                                ),
                              )
                            : Icon(
                                Icons.volume_up_outlined,
                                size: 18,
                                color: (isBlocked ||
                                        _playingMessageId != null)
                                    ? Colors.grey[300]
                                    : const Color(0xFF4DB6AC),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Status pill (Listening / Thinking / Speaking) ----
  Widget _buildStatusPill(ActiveSessionState sessionState) {
    String? label;
    IconData? icon;
    Color bgColor = Colors.grey.shade100;
    Color borderColor = Colors.grey.shade300;
    Color textColor = Colors.grey.shade600;
    Widget? leading;

    if (sessionState.isRecording && sessionState.liveTranscript.isEmpty) {
      label = 'Listening...';
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      textColor = Colors.red;
      leading = Container(
        width: 7,
        height: 7,
        decoration:
            const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
      );
    } else if (sessionState.isSpeaking) {
      label = 'Speaking...';
      icon = Icons.volume_up_outlined;
      bgColor = const Color(0xFFE0F2F1);
      borderColor = const Color(0xFF4DB6AC);
      textColor = const Color(0xFF1F7A7E);
    } else if (sessionState.isLoading) {
      label = 'Thinking...';
      bgColor = Colors.grey.shade100;
      borderColor = Colors.grey.shade300;
      textColor = Colors.grey.shade600;
      leading = SizedBox(
        width: 11,
        height: 11,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(Colors.grey.shade600),
        ),
      );
    }

    if (label == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 7)],
              if (icon != null) ...[
                Icon(icon, size: 14, color: textColor),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Input bar ----
  Widget _buildInputBar(
      BuildContext context, ActiveSessionState sessionState) {
    final isProcessing = sessionState.isLoading || sessionState.isSpeaking;
    final canSend =
        _hasText && !isProcessing && !sessionState.isRecording;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Mic button
            GestureDetector(
              onTap: isProcessing
                  ? null
                  : (sessionState.isRecording
                      ? _stopListeningAndSend
                      : _startListening),
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sessionState.isRecording
                      ? Colors.red
                      : (isProcessing
                          ? Colors.grey.shade300
                          : const Color(0xFF1F7A7E)),
                ),
                child: Icon(
                  sessionState.isRecording ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            // Text input
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled:
                    !sessionState.isRecording && !sessionState.isSpeaking,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: sessionState.isRecording
                      ? 'Recording...'
                      : (sessionState.isSpeaking
                          ? 'Playing...'
                          : 'Type your response...'),
                  hintStyle:
                      TextStyle(color: Colors.grey[400], fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
                onSubmitted: (_) => canSend ? _sendMessage() : null,
              ),
            ),
            // Send button
            GestureDetector(
              onTap: canSend ? _sendMessage : null,
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: canSend
                      ? const Color(0xFF1F7A7E)
                      : Colors.grey.shade200,
                ),
                child: isProcessing && !sessionState.isRecording
                    ? Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              canSend
                                  ? Colors.white
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: canSend
                            ? Colors.white
                            : Colors.grey.shade400,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Objectives Expandable Panel ----
  Widget _buildObjectivesPanel(ActiveSessionState sessionState) {
    final completed = sessionState.objectivesCompleted.length;
    final isLoading = completed == 0 && sessionState.maxScore == 0;

    return Container(
      color: Colors.blue.shade50,
      child: Column(
        children: [
          // Summary header (always visible)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading
                  ? null
                  : () =>
                      setState(() => _objectivesExpanded = !_objectivesExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      _objectivesExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Objectives',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (isLoading)
                            Text(
                              'Loading objectives...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else
                            Text(
                              '$completed / ${completed + (sessionState.maxScore > 0 ? ((sessionState.maxScore - sessionState.currentScore) ~/ 10) : 0)} completed',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!isLoading)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade200.withValues(
                              alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$completed/${completed + (sessionState.maxScore > 0 ? ((sessionState.maxScore - sessionState.currentScore) ~/ 10) : 0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Expanded content
          if (_objectivesExpanded && !isLoading && sessionState.objectivesCompleted.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sessionState.objectivesCompleted.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final obj =
                          sessionState.objectivesCompleted[index];
                      return Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  obj.objective.label,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (obj.notes != null &&
                                    obj.notes!.isNotEmpty)
                                  Padding(
                                    padding:
                                        const EdgeInsets
                                            .only(top: 4),
                                    child: Text(
                                      obj.notes!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors
                                            .grey.shade600,
                                        fontStyle:
                                            FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '+${obj.pointsAwarded}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          if (_objectivesExpanded && !isLoading &&
              sessionState.objectivesCompleted.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'No objectives completed yet. Keep working to achieve them!',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:convora/core/providers/providers.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  int? _currentVote;  // -1, 0, or 1
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitFeedback() async {
    final sessionState = ref.read(activeSessionProvider);
    if (sessionState.sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No active session')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.submitFeedback(
        sessionId: sessionState.sessionId!,
        vote: _currentVote ?? 0,
        comment: _commentController.text.isEmpty ? null : _commentController.text,
      );

      if (mounted) {
        // Reset session state and navigate to dashboard
        ref.read(activeSessionProvider.notifier).reset();
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting feedback: $e')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _skip() {
    ref.read(activeSessionProvider.notifier).reset();
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(activeSessionProvider);
    final endData = sessionState.sessionEndData;

    // Show loading if endSession hasn't completed yet
    if (endData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Session Complete'),
          automaticallyImplyLeading: false,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your results...'),
            ],
          ),
        ),
      );
    }

    final finalScore = endData.finalScore.toDouble();
    final percentage = (finalScore / 100.0).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Complete'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Score ring
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      height: 200,
                      width: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 200,
                            width: 200,
                            child: CircularProgressIndicator(
                              value: percentage,
                              strokeWidth: 8,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation(
                                _getScoreColor(finalScore),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                endData.finalScore.toString(),
                                style: Theme.of(context)
                                    .textTheme
                                    .displayLarge,
                              ),
                              const Text('Points'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _getScoreInterpretation(finalScore),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (endData.appointmentSet)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Chip(
                          backgroundColor: Colors.green.shade100,
                          label: const Text(
                            '✓ Appointment Set',
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Personality revealed card
              Card(
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_search, color: Colors.teal),
                          const SizedBox(width: 8),
                          Text(
                            'Personality Revealed',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.teal.shade700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _infoRow(context, 'Occupation',
                          endData.personality.occupation),
                      _infoRow(context, 'DISC Type', endData.discType),
                      _infoRow(
                        context,
                        'Traits',
                        '${endData.traitSet.trait1} · ${endData.traitSet.trait2} · ${endData.traitSet.trait3}',
                      ),
                      if (endData.personality.hiddenMotivation != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Hidden Motivation',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: Colors.teal.shade700),
                        ),
                        Text(endData.personality.hiddenMotivation!),
                      ],
                      if (endData.personality.redFlags != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Red Flags',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: Colors.red.shade700),
                        ),
                        Text(endData.personality.redFlags!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Objectives card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Objectives',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (endData.objectives.isEmpty)
                        const Text('No objectives were completed.')
                      else
                        for (final obj in endData.objectives)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  obj.pointsAwarded > 0
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: obj.pointsAwarded > 0
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(obj.objective.label),
                                      if (obj.notes != null)
                                        Text(
                                          obj.notes!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  obj.pointsAwarded > 0
                                      ? '+${obj.pointsAwarded}'
                                      : '0',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: obj.pointsAwarded > 0
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Feedback Section
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How was this scenario?',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      // Thumbs up/down buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildVoteButton(
                            context,
                            icon: Icons.thumb_down,
                            label: 'Dislike',
                            vote: -1,
                            isSelected: _currentVote == -1,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 16),
                          _buildVoteButton(
                            context,
                            icon: Icons.thumb_up,
                            label: 'Like',
                            vote: 1,
                            isSelected: _currentVote == 1,
                            color: Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Comment field
                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Add a comment (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitFeedback,
                icon: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit Feedback'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _skip,
                icon: const Icon(Icons.skip_next),
                label: const Text('Skip'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoteButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int vote,
    required bool isSelected,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentVote = _currentVote == vote ? null : vote;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Colors.teal.shade700),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.yellow.shade700;
    return Colors.red;
  }

  String _getScoreInterpretation(double score) {
    if (score >= 80) return 'Excellent Performance!';
    if (score >= 60) return 'Good Job!';
    if (score >= 40) return 'Solid Effort';
    return 'Keep Practicing';
  }
}

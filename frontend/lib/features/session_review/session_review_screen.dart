import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:convora/core/api/convora_api.dart';
import 'package:convora/core/providers/providers.dart';

String _formatDateTime(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final min = dt.minute.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $hour:$min $ampm';
}

String _formatTime(DateTime dt) {
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final min = dt.minute.toString().padLeft(2, '0');
  return '$hour:$min $ampm';
}

class SessionReviewScreen extends ConsumerWidget {
  final int sessionId;

  const SessionReviewScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(sessionReviewProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Review'),
        leading: BackButton(
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: reviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Failed to load session: $error',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.refresh(sessionReviewProvider(sessionId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (review) {
          final percentage = (review.finalScore / 100.0).clamp(0.0, 1.0);
          final scoreColor = _getScoreColor(review.finalScore.toDouble());

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ────────────────────────────────────────────────
                Text(
                  review.scenarioTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _StatusChip(status: review.status),
                    const SizedBox(width: 8),
                    if (review.endedAt != null)
                      Text(
                        _formatDateTime(review.endedAt!.toLocal()),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Score Ring ────────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 160,
                        width: 160,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              height: 160,
                              width: 160,
                              child: CircularProgressIndicator(
                                value: percentage,
                                strokeWidth: 8,
                                backgroundColor: Colors.grey.shade300,
                                valueColor:
                                    AlwaysStoppedAnimation(scoreColor),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  review.finalScore.toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium,
                                ),
                                const Text('Points'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _getScoreLabel(review.finalScore.toDouble()),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (review.appointmentSet)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Chip(
                            backgroundColor: Colors.green.shade100,
                            label: const Text('✓ Appointment Set',
                                style: TextStyle(color: Colors.green)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Score Breakdown ───────────────────────────────────────
                if (review.scoreEvents.isNotEmpty) ...[
                  _SectionHeader(
                      icon: Icons.bar_chart, title: 'Score Breakdown'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: review.scoreEvents
                            .where((e) => e.points != 0)
                            .map((e) => ListTile(
                                  dense: true,
                                  leading: _EventTypeBadge(
                                      eventType: e.eventType),
                                  title: Text(
                                    e.label ?? e.eventType,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: e.reason != null
                                      ? Text(e.reason!,
                                          style: const TextStyle(
                                              fontSize: 12))
                                      : null,
                                  trailing: Text(
                                    '${e.points > 0 ? '+' : ''}${e.points}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: e.points > 0
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Objectives ────────────────────────────────────────────
                _SectionHeader(
                    icon: Icons.checklist_rtl, title: 'Objectives'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: review.objectives.isEmpty
                        ? const Text('No objectives tracked.')
                        : Column(
                            children: review.objectives
                                .map((obj) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            obj.achieved
                                                ? Icons.check_circle
                                                : Icons.cancel,
                                            color: obj.achieved
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    obj.objective.label,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500)),
                                                if (obj.notes != null)
                                                  Text(obj.notes!,
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey)),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '+${obj.pointsAwarded} pts',
                                            style: TextStyle(
                                                color:
                                                    Colors.teal.shade700,
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Personality Reveal ────────────────────────────────────
                _SectionHeader(
                    icon: Icons.person_search,
                    title: 'Personality Revealed'),
                Card(
                  color: Colors.teal.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow(context, 'Occupation',
                            review.personality.occupation),
                        _infoRow(context, 'DISC Type', review.discType),
                        _infoRow(
                          context,
                          'Traits',
                          '${review.traitSet.trait1} · ${review.traitSet.trait2} · ${review.traitSet.trait3}',
                        ),
                        if (review.personality.hiddenMotivation != null) ...[
                          const SizedBox(height: 8),
                          Text('Hidden Motivation',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      color: Colors.teal.shade700)),
                          Text(review.personality.hiddenMotivation!),
                        ],
                        if (review.personality.redFlags != null) ...[
                          const SizedBox(height: 8),
                          Text('Red Flags',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      color: Colors.red.shade700)),
                          Text(review.personality.redFlags!),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Transcript ────────────────────────────────────────────
                _SectionHeader(
                    icon: Icons.chat_bubble_outline,
                    title: 'Conversation Transcript'),
                ...review.messages
                    .where((m) => m.role != 'tool_result')
                    .map((m) => _MessageBubble(message: m)),
                const SizedBox(height: 32),

                // ── Vote Card ────────────────────────────────────────────
                _ScenarioVoteCard(
                  sessionId: sessionId,
                  scenarioId: review.scenarioId,
                ),
                const SizedBox(height: 32),

                // ── Retake Button ─────────────────────────────────────────
                FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake Scenario'),
                  onPressed: () async {
                    await ref
                        .read(activeSessionProvider.notifier)
                        .startSession(
                            review.scenarioId, review.scenarioTitle);
                    if (context.mounted) context.go('/training');
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/history'),
                  child: const Text('Back to History'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: Colors.teal.shade700)),
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

  String _getScoreLabel(double score) {
    if (score >= 80) return 'Excellent Performance!';
    if (score >= 60) return 'Good Job!';
    if (score >= 40) return 'Solid Effort';
    return 'Keep Practicing';
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.teal),
          const SizedBox(width: 8),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'completed'
        ? Colors.green
        : status == 'abandoned'
            ? Colors.red
            : Colors.blue;
    return Chip(
      label: Text(status,
          style: TextStyle(color: color.shade800, fontSize: 12)),
      backgroundColor: color.shade100,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }
}

class _EventTypeBadge extends StatelessWidget {
  final String eventType;

  const _EventTypeBadge({required this.eventType});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (eventType) {
      case 'objective':
        color = Colors.teal;
        break;
      case 'bonus':
        color = Colors.orange;
        break;
      case 'disc_alignment':
        color = Colors.purple;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        eventType.replaceAll('_', ' '),
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final SessionMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            const Padding(
              padding: EdgeInsets.only(right: 8, top: 4),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.teal,
                child: Icon(Icons.smart_toy, size: 16, color: Colors.white),
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Colors.teal.shade600
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Text(
                    _formatTime(message.createdAt.toLocal()),
                    style: const TextStyle(
                        fontSize: 10, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          if (isUser)
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 4),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Vote Card Widget ──────────────────────────────────────────────────
class _ScenarioVoteCard extends ConsumerStatefulWidget {
  final int sessionId;
  final int scenarioId;

  const _ScenarioVoteCard({
    required this.sessionId,
    required this.scenarioId,
  });

  @override
  ConsumerState<_ScenarioVoteCard> createState() => _ScenarioVoteCardState();
}

class _ScenarioVoteCardState extends ConsumerState<_ScenarioVoteCard> {
  int? _currentVote;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitVote() async {
    setState(() => _isSubmitting = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.submitFeedback(
        sessionId: widget.sessionId,
        vote: _currentVote ?? 0,
        comment: _commentController.text.isEmpty ? null : _commentController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted!')),
        );
        setState(() {
          _isSubmitting = false;
          _currentVote = null;
          _commentController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.thumb_up_outlined, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'How was this scenario?',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Vote buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildVoteButton(
                  icon: Icons.thumb_down,
                  label: 'Dislike',
                  vote: -1,
                  isSelected: _currentVote == -1,
                  color: Colors.red,
                ),
                const SizedBox(width: 16),
                _buildVoteButton(
                  icon: Icons.thumb_up,
                  label: 'Like',
                  vote: 1,
                  isSelected: _currentVote == 1,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Comment field (condensed)
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText:'Optional comment',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitVote,
              child: Text(_isSubmitting ? 'Submitting...' : 'Submit Feedback'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

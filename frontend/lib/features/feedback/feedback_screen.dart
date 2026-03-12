import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:convora/core/providers/providers.dart';

class FeedbackScreen extends ConsumerWidget {
  const FeedbackScreen({super.key});

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

              ElevatedButton.icon(
                onPressed: () {
                  ref.read(activeSessionProvider.notifier).reset();
                  context.go('/home');
                },
                icon: const Icon(Icons.home),
                label: const Text('Back to Home'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(activeSessionProvider.notifier).reset();
                  context.go('/home');
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Try Another Session'),
              ),
            ],
          ),
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

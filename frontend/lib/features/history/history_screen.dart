import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:convora/core/providers/providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(sessionHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
        leading: BackButton(
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(sessionHistoryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No session history yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start a training session to see your history here!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final date = DateTimeHelper.parse(session.endedAt ?? session.startedAt);
              final dateStr = DateTimeHelper.format(date);

              return GestureDetector(
                onTap: () => context.push('/session-review/${session.id}'),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and status badge row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                session.scenarioTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(
                                session.status,
                                style: TextStyle(
                                  color: session.status == 'completed'
                                      ? Colors.green.shade800
                                      : Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              backgroundColor: session.status == 'completed'
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Date and score row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateStr,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                'Score: ${session.score}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Helper to parse and format dates
class DateTimeHelper {
  static DateTime parse(String date) {
    return DateTime.parse(date);
  }

  static String format(DateTime date) {
    final localDate = date.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final ampm = localDate.hour >= 12 ? 'PM' : 'AM';
    final hour = localDate.hour % 12 == 0 ? 12 : localDate.hour % 12;
    final min = localDate.minute.toString().padLeft(2, '0');
    return '${months[localDate.month - 1]} ${localDate.day}, ${localDate.year}  $hour:$min $ampm';
  }
}

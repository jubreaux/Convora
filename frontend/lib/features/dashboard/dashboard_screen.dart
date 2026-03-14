import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:convora/core/providers/providers.dart';
import 'package:convora/features/auth/auth_screen.dart' show showServerDialog;
import 'widgets/stat_card.dart';
import 'widgets/score_chart.dart';
import 'widgets/disc_breakdown_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Convora'),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Session History'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onTap: () {
                  context.go('/home');
                },
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.dns_outlined),
                  title: Text('Change Server'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onTap: () => Future.microtask(
                  () => showServerDialog(context, ref),
                ),
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onTap: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/login');
                },
              ),
            ],
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load stats',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(userStatsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${authState.user?.name.split(' ').first}!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ready to sharpen your skills?',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Key Stats Grid (2x2)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  StatCard(
                    label: 'Total Sessions',
                    value: stats.totalSessions.toString(),
                    icon: Icons.school_rounded,
                    color: Colors.teal,
                  ),
                  StatCard(
                    label: 'Avg Score',
                    value: '${stats.avgScore.toStringAsFixed(1)}',
                    icon: Icons.trending_up_rounded,
                    color: Colors.blue,
                  ),
                  StatCard(
                    label: 'Best Score',
                    value: stats.bestScore.toString(),
                    icon: Icons.emoji_events_rounded,
                    color: Colors.orange,
                  ),
                  StatCard(
                    label: 'Appointment Rate',
                    value: '${stats.appointmentRate.toStringAsFixed(0)}%',
                    icon: Icons.event_available_rounded,
                    color: Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Score Progression Section
              Text(
                'Score Progression',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ScoreLineChart(
                  timeline: stats.timeline,
                  maxScore: stats.bestScore > 0 ? stats.bestScore : 100,
                ),
              ),
              const SizedBox(height: 32),

              // DISC Breakdown Section
              Text(
                'Performance by Personality Type',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              DiscBreakdownCard(
                discBreakdown: stats.discBreakdown,
              ),
              const SizedBox(height: 32),

              // Scenario Performance Section
              if (stats.scenarioPerformance.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance by Scenario',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: stats.scenarioPerformance.length,
                      itemBuilder: (context, index) {
                        final scenario = stats.scenarioPerformance[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        scenario.scenarioTitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
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
                                        'Avg: ${scenario.avgScore.toStringAsFixed(1)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: Colors.teal.shade100,
                                      labelStyle:
                                          TextStyle(color: Colors.teal.shade800),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${scenario.sessionCount} session${scenario.sessionCount != 1 ? 's' : ''}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey.shade600,
                                          ),
                                    ),
                                    Text(
                                      'Best: ${scenario.bestScore}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade700,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Score progress bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: scenario.avgScore / 100,
                                    minHeight: 6,
                                    backgroundColor:
                                        Colors.grey.shade300,
                                    valueColor: AlwaysStoppedAnimation(
                                      scenario.avgScore >= 80
                                          ? Colors.green.shade500
                                          : scenario.avgScore >= 60
                                              ? Colors.blue.shade500
                                              : Colors.orange.shade500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              // CTA Button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Start a Conversation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

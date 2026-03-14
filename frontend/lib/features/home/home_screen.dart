import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:convora/core/providers/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenariosAsync = ref.watch(scenariosProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Convora Training'),
          actions: [
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Text('Logout'),
                  onTap: () {
                    ref.read(authProvider.notifier).logout();
                    context.go('/login');
                  },
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Scenarios'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ScenariosTab(scenariosAsync: scenariosAsync),
            _HistoryTab(),
          ],
        ),
      ),
    );
  }
}

class _ScenariosTab extends ConsumerWidget {
  final AsyncValue scenariosAsync;

  const _ScenariosTab({required this.scenariosAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return scenariosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.refresh(scenariosProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (scenarios) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _launchRandomScenario(context, ref),
              icon: const Icon(Icons.shuffle),
              label: const Text('Surprise Me'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: scenarios.length,
              itemBuilder: (context, index) {
                final scenario = scenarios[index];
                return ListTile(
                  title: Text(scenario.title),
                  subtitle: Text(_getDiscDescription(scenario.discType)),
                  trailing: Chip(
                    label: Text(scenario.discType),
                    backgroundColor:
                        _getDiscColor(scenario.discType),
                  ),
                  onTap: () => _startSession(context, ref, scenario.id, scenario.title),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getDiscDescription(String discType) {
    switch (discType.toUpperCase()) {
      case 'D':
        return 'D – Dominant (Direct, Results-Oriented)';
      case 'I':
        return 'I – Influential (Enthusiastic, Relationship-Focused)';
      case 'S':
        return 'S – Steady (Patient, Supportive)';
      case 'C':
        return 'C – Conscientious (Analytical, Detail-Oriented)';
      default:
        return 'Unknown Personality Type';
    }
  }

  void _startSession(BuildContext context, WidgetRef ref, int scenarioId, String scenarioTitle) async {
    await ref.read(activeSessionProvider.notifier).startSession(scenarioId, scenarioTitle);
    if (context.mounted) {
      context.go('/training');
    }
  }

  void _launchRandomScenario(BuildContext context, WidgetRef ref) {
    ref.read(randomScenarioProvider).whenData((scenario) {
      _startSession(context, ref, scenario.id, scenario.title);
    });
  }

  Color _getDiscColor(String disc) {
    switch (disc.toUpperCase()) {
      case 'D':
        return Colors.red.shade300;
      case 'I':
        return Colors.orange.shade300;
      case 'S':
        return Colors.green.shade300;
      case 'C':
        return Colors.blue.shade300;
      default:
        return Colors.grey.shade300;
    }
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(sessionHistoryProvider);

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error'),
      ),
      data: (sessions) {
        if (sessions.isEmpty) {
          return const Center(
            child: Text('No session history yet.\nStart a training session!'),
          );
        }
        return ListView.builder(
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            return ListTile(
              title: Text('Score: ${session.score}'),
              subtitle: Text(session.endedAt?.toString() ?? 'In Progress'),
              trailing: Text(
                session.status,
                style: TextStyle(
                  color: session.status == 'completed'
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

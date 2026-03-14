import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:convora/core/providers/providers.dart';
import 'package:convora/features/auth/auth_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenariosAsync = ref.watch(scenariosProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final userOrgId = user?.orgId;
    final userOrgRole = user?.orgRole;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Convora Training'),
              if (userOrgId != null && userOrgRole != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Corporate Account • ${userOrgRole.toUpperCase()}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            PopupMenuButton(
              itemBuilder: (context) => [
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
            const _HistoryTab(),
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Visibility badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getVisibilityColor(scenario.visibility).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getVisibilityColor(scenario.visibility),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          _getVisibilityLabel(scenario.visibility),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getVisibilityColor(scenario.visibility),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // DISC type chip
                      Chip(
                        label: Text(scenario.discType),
                        backgroundColor: _getDiscColor(scenario.discType),
                      ),
                    ],
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

  Color _getVisibilityColor(String visibility) {
    switch (visibility.toLowerCase()) {
      case 'personal':
        return Colors.purple;
      case 'org':
        return Colors.indigo;
      case 'default':
        return Colors.cyan;
      case 'public':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getVisibilityLabel(String visibility) {
    switch (visibility.toLowerCase()) {
      case 'personal':
        return 'Personal';
      case 'org':
        return 'Organization';
      case 'default':
        return 'Platform';
      case 'public':
        return 'Public';
      default:
        return visibility;
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
            final date = session.endedAt ?? session.startedAt;
            final dateStr =
                '${date.month}/${date.day}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
            return ListTile(
              title: Text(
                session.scenarioTitle,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text('Score: ${session.score}   •   $dateStr'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    label: Text(session.status),
                    backgroundColor: session.status == 'completed'
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    labelStyle: TextStyle(
                      color: session.status == 'completed'
                          ? Colors.green.shade800
                          : Colors.orange.shade800,
                      fontSize: 12,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              onTap: () => context.push('/session-review/${session.id}'),
            );
          },
        );
      },
    );
  }
}

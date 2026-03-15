import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:convora/core/providers/providers.dart';
import 'package:convora/core/models/models.dart';

class TeamsOverviewScreen extends ConsumerWidget {
  const TeamsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(orgTeamsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(orgTeamsProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load teams',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(error.toString(),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(orgTeamsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (teams) {
          if (teams.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_rounded,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No teams yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text('Create your first team to organize members and track performance.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateTeamDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Team'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Summary bar
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.teal.shade50,
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryChip(
                        label: 'Total Teams',
                        value: teams.length.toString(),
                        icon: Icons.groups_rounded,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryChip(
                        label: 'Total Members',
                        value: teams.fold(0, (sum, t) => sum + t.memberCount).toString(),
                        icon: Icons.people_rounded,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryChip(
                        label: 'Org Avg Score',
                        value: teams.isEmpty
                            ? '0'
                            : (teams.fold(0.0, (sum, t) => sum + t.avgScore) / teams.length).toStringAsFixed(1),
                        icon: Icons.trending_up_rounded,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              // Teams list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: teams.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    return _TeamCard(team: team);
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Team'),
        onPressed: () => _showCreateTeamDialog(context, ref),
      ),
    );
  }

  void _showCreateTeamDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Team Name',
                hintText: 'e.g., Sales Team',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Team description',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Team name is required')),
                );
                return;
              }

              try {
                await ref.read(apiClientProvider).createOrgTeam(
                  nameController.text,
                  descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text,
                );
                ref.refresh(orgTeamsProvider);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Team created successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Team Card
// ===========================================================================

class _TeamCard extends StatelessWidget {
  final TeamStats team;

  const _TeamCard({required this.team});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/org-teams/${team.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (team.description != null)
                          Text(
                            team.description!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 12),
              // Stats row
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _StatPill(
                    icon: Icons.people_rounded,
                    label: '${team.memberCount} members',
                    color: Colors.teal,
                  ),
                  _StatPill(
                    icon: Icons.school_rounded,
                    label: '${team.totalSessions} sessions',
                    color: Colors.blue,
                  ),
                  _StatPill(
                    icon: Icons.trending_up_rounded,
                    label: 'Avg ${team.avgScore.toStringAsFixed(1)}',
                    color: Colors.orange,
                  ),
                  _StatPill(
                    icon: Icons.event_available_rounded,
                    label: '${team.appointmentRate.toStringAsFixed(0)}% appt',
                    color: Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Summary Chip
// ===========================================================================

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ===========================================================================
// Stat Pill
// ===========================================================================

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

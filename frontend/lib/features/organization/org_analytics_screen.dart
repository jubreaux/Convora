import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convora/core/providers/providers.dart';
import 'package:convora/core/models/models.dart';

class OrgAnalyticsScreen extends ConsumerWidget {
  const OrgAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(orgAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Performance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(orgAnalyticsProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load analytics',
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
                onPressed: () => ref.refresh(orgAnalyticsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (members) {
          if (members.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart_rounded,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No data yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text('Stats will appear once team members complete sessions.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }

          // Sort by avg score descending
          final sorted = [...members]
            ..sort((a, b) => b.avgScore.compareTo(a.avgScore));

          // Compute org totals
          final totalSessions =
              sorted.fold(0, (sum, m) => sum + m.totalSessions);
          final avgScore = sorted.isEmpty
              ? 0.0
              : sorted.fold(0.0, (sum, m) => sum + m.avgScore) /
                  sorted.length;
          final avgApptRate = sorted.isEmpty
              ? 0.0
              : sorted.fold(0.0, (sum, m) => sum + m.appointmentRate) /
                  sorted.length;

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
                        label: 'Total Sessions',
                        value: totalSessions.toString(),
                        icon: Icons.school_rounded,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryChip(
                        label: 'Team Avg Score',
                        value: avgScore.toStringAsFixed(1),
                        icon: Icons.trending_up_rounded,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryChip(
                        label: 'Appt Rate',
                        value: '${avgApptRate.toStringAsFixed(0)}%',
                        icon: Icons.event_available_rounded,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              // Members list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final member = sorted[index];
                    return _AnalyticsTile(member: member, rank: index + 1);
                  },
                ),
              ),
            ],
          );
        },
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
// Analytics Tile
// ===========================================================================

class _AnalyticsTile extends StatelessWidget {
  final OrgMemberStats member;
  final int rank;

  const _AnalyticsTile({required this.member, required this.rank});

  @override
  Widget build(BuildContext context) {
    final rankColor = rank == 1
        ? Colors.amber
        : rank == 2
            ? Colors.blueGrey.shade400
            : rank == 3
                ? Colors.brown.shade300
                : Colors.grey.shade300;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rank badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: rankColor,
                  shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: rank <= 3 ? Colors.white : Colors.grey.shade700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Member info + stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(member.userName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                            overflow: TextOverflow.ellipsis),
                      ),
                      _RoleBadge(role: member.orgRole),
                    ],
                  ),
                  Text(member.userEmail,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600)),
                  const SizedBox(height: 10),
                  // Stats row
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _StatPill(
                        icon: Icons.school_rounded,
                        label: '${member.totalSessions} sessions',
                        color: Colors.teal,
                      ),
                      _StatPill(
                        icon: Icons.trending_up_rounded,
                        label:
                            'Avg ${member.avgScore.toStringAsFixed(1)}',
                        color: Colors.blue,
                      ),
                      _StatPill(
                        icon: Icons.emoji_events_rounded,
                        label: 'Best ${member.bestScore}',
                        color: Colors.orange,
                      ),
                      _StatPill(
                        icon: Icons.event_available_rounded,
                        label:
                            '${member.appointmentRate.toStringAsFixed(0)}% appt',
                        color: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade700)),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (role) {
      case 'org_admin':
        color = Colors.teal;
        label = 'Admin';
        break;
      case 'team_lead':
        color = Colors.blue;
        label = 'Team Lead';
        break;
      default:
        color = Colors.grey;
        label = 'Member';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:convora/core/models/models.dart';

class DiscBreakdownCard extends StatelessWidget {
  final Map<String, DiscTypeStats> discBreakdown;

  const DiscBreakdownCard({
    super.key,
    required this.discBreakdown,
  });

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

  String _getDiscFullName(String disc) {
    switch (disc.toUpperCase()) {
      case 'D':
        return 'Dominant';
      case 'I':
        return 'Influential';
      case 'S':
        return 'Steady';
      case 'C':
        return 'Conscientious';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: ['D', 'I', 'S', 'C'].map((disc) {
        final stats = discBreakdown[disc];
        final color = _getDiscColor(disc);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.15),
                  Colors.white,
                ],
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // DISC type header
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      disc,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getDiscFullName(disc),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                ),
                const Spacer(),
                // Stats
                if (stats != null && stats.sessionCount > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stats.sessionCount} session${stats.sessionCount != 1 ? 's' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Avg: ${stats.avgScore.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                      ),
                    ],
                  )
                else
                  Center(
                    child: Text(
                      'No sessions',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:convora/core/providers/providers.dart';
import 'create_scenario_sheet.dart';
import 'edit_scenario_sheet.dart';

class ScenariosScreen extends ConsumerWidget {
  const ScenariosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenariosAsync = ref.watch(scenariosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Scenario'),
        leading: BackButton(
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: scenariosAsync.when(
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
                onPressed: () => ref.refresh(scenariosProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (scenarios) => Column(
          children: [
            // Top section with buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Surprise Me button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchRandomScenario(context, ref),
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Surprise Me'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Scenario cards grid
            Expanded(
              child: scenarios.isEmpty
                  ? const Center(
                      child: Text('No scenarios available'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: scenarios.length,
                      itemBuilder: (context, index) {
                        final scenario = scenarios[index];
                        return GestureDetector(
                          onTap: () =>
                              _startSession(context, ref, scenario.id, scenario.title),
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
                                  // Title and visibility badge row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          scenario.title,
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getVisibilityColor(scenario.visibility)
                                              .withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _getVisibilityColor(
                                                scenario.visibility),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Text(
                                          _getVisibilityLabel(scenario.visibility),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _getVisibilityColor(
                                                scenario.visibility),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Edit button (only for personal scenarios)
                                      if (scenario.visibility == 'personal')
                                        IconButton(
                                          onPressed: () => showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            builder: (context) =>
                                                EditScenarioSheet(scenario: scenario),
                                          ),
                                          icon: const Icon(Icons.edit_outlined),
                                          iconSize: 20,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // DISC type and transaction type row
                                  Row(
                                    children: [
                                      Chip(
                                        label: Text(scenario.discType),
                                        backgroundColor:
                                            _getDiscColor(scenario.discType),
                                        labelStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (scenario.transactionType != null)
                                        Chip(
                                          label: Text(scenario.transactionType!),
                                          backgroundColor: Colors.grey.shade300,
                                          labelStyle: const TextStyle(
                                            fontSize: 12,
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
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => const CreateScenarioSheet(),
        ),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _startSession(BuildContext context, WidgetRef ref, int scenarioId,
      String scenarioTitle) async {
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

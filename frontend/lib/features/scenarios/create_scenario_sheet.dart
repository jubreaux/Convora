import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convora/core/providers/providers.dart';

class CreateScenarioSheet extends ConsumerStatefulWidget {
  const CreateScenarioSheet({super.key});

  @override
  ConsumerState<CreateScenarioSheet> createState() => _CreateScenarioSheetState();
}

class _CreateScenarioSheetState extends ConsumerState<CreateScenarioSheet> {
  late TextEditingController _titleController;
  late TextEditingController _promptController;
  
  String _selectedDiscType = 'D';
  String _selectedVisibility = 'personal';
  bool _isLoading = false;

  final List<String> _discTypes = ['D', 'I', 'S', 'C'];
  final List<Map<String, String>> _visibilityOptions = [
    {'label': 'Personal', 'value': 'personal'},
    {'label': 'Organization', 'value': 'org'},
    {'label': 'Public', 'value': 'public'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _promptController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Color _getDiscColor(String discType) {
    switch (discType) {
      case 'D':
        return Colors.red.shade400;
      case 'I':
        return Colors.orange.shade400;
      case 'S':
        return Colors.green.shade400;
      case 'C':
        return Colors.blue.shade400;
      default:
        return Colors.grey;
    }
  }

  String _getDiscLabel(String discType) {
    switch (discType) {
      case 'D':
        return 'Dominant';
      case 'I':
        return 'Influencer';
      case 'S':
        return 'Steady';
      case 'C':
        return 'Conscientious';
      default:
        return 'Unknown';
    }
  }

  Future<void> _createScenario() async {
    if (_titleController.text.isEmpty || _promptController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.createScenario(
        title: _titleController.text,
        discType: _selectedDiscType,
        aiSystemPrompt: _promptController.text,
        visibility: _selectedVisibility,
      );

      // Invalidate scenarios provider to refresh the list
      ref.invalidate(scenariosProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scenario created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating scenario: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create New Scenario',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Title field
            TextField(
              controller: _titleController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'Scenario Title',
                hintText: 'e.g., First-time home buyer meeting',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 18),

            // DISC Type selector
            Text(
              'DISC Personality Type',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _discTypes.map((discType) {
                final isSelected = _selectedDiscType == discType;
                return ChoiceChip(
                  selected: isSelected,
                  onSelected: _isLoading
                      ? null
                      : (selected) {
                          setState(() => _selectedDiscType = discType);
                        },
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected
                        ? _getDiscColor(discType)
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  label: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          discType,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? _getDiscColor(discType)
                                : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          _getDiscLabel(discType),
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? _getDiscColor(discType)
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // System Prompt field
            TextField(
              controller: _promptController,
              enabled: !_isLoading,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'System Prompt',
                hintText:
                    'What is the goal? How should Claude behave? What is the context?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),

            // Visibility selector
            Text(
              'Visibility',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: _visibilityOptions
                  .map(
                    (opt) => ButtonSegment<String>(
                      value: opt['value']!,
                      label: Text(opt['label']!),
                    ),
                  )
                  .toList(),
              selected: {_selectedVisibility},
              onSelectionChanged: _isLoading
                  ? null
                  : (newSelection) {
                      setState(() => _selectedVisibility = newSelection.first);
                    },
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _createScenario,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(_isLoading ? 'Creating...' : 'Create'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

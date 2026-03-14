import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convora/core/providers/providers.dart';
import 'package:convora/core/models/models.dart';

class EditScenarioSheet extends ConsumerStatefulWidget {
  final ScenarioList scenario;

  const EditScenarioSheet({
    super.key,
    required this.scenario,
  });

  @override
  ConsumerState<EditScenarioSheet> createState() => _EditScenarioSheetState();
}

class _EditScenarioSheetState extends ConsumerState<EditScenarioSheet> {
  late TextEditingController _titleController;
  late TextEditingController _promptController;

  late String _selectedDiscType;
  late String _selectedVisibility;
  bool _isLoading = true;  // Start true while loading detail
  bool _isSaving = false;
  String? _loadError;

  final List<String> _discTypes = ['D', 'I', 'S', 'C'];
  final List<Map<String, String>> _visibilityOptions = [
    {'label': 'Personal', 'value': 'personal'},
    {'label': 'Organization', 'value': 'org'},
    {'label': 'Public', 'value': 'public'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.scenario.title);
    _promptController = TextEditingController();
    _selectedDiscType = widget.scenario.discType;
    _selectedVisibility = widget.scenario.visibility;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final detail = await apiClient.getScenarioDetail(widget.scenario.id);
      if (mounted) {
        _promptController.text = detail.aiSystemPrompt;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Failed to load scenario details: $e';
        });
      }
    }
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

  Future<void> _updateScenario() async {
    if (_titleController.text.isEmpty || _promptController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.updateScenario(
        scenarioId: widget.scenario.id,
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
          const SnackBar(content: Text('Scenario updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating scenario: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading spinner while fetching scenario detail
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Show error if detail fetch failed
    if (_loadError != null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 40, color: Colors.red),
                const SizedBox(height: 12),
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                  'Edit Scenario',
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
              enabled: !_isSaving,
              decoration: InputDecoration(
                labelText: 'Scenario Title',
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
                  onSelected: _isSaving
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
              enabled: !_isSaving,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'System Prompt',
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
              onSelectionChanged: _isSaving
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
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _updateScenario,
                    icon: _isSaving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save'),
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

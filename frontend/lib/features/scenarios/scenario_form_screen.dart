import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:convora/core/providers/providers.dart';
import 'package:convora/core/models/models.dart';

class ScenarioFormScreen extends ConsumerStatefulWidget {
  final ScenarioDetail? scenario;  // null = create, non-null = edit

  const ScenarioFormScreen({
    super.key,
    this.scenario,
  });

  @override
  ConsumerState<ScenarioFormScreen> createState() => _ScenarioFormScreenState();
}

class _ScenarioFormScreenState extends ConsumerState<ScenarioFormScreen> {
  late TextEditingController _titleController;
  late TextEditingController _promptController;

  String _selectedDiscType = 'D';
  String _selectedVisibility = 'personal';
  int? _selectedPersonalityTemplateId;
  int? _selectedTraitSetId;
  int? _selectedScenarioContextId;

  List<Map<String, dynamic>> _objectives = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  ScenarioDetail? _fullScenario;
  List<PersonalityTemplate>? _personalityTemplates;
  List<TraitSet>? _traitSets;
  List<ScenarioContext>? _scenarioContexts;

  final List<Map<String, String>> _discOptions = [
    {'label': 'Dominant', 'value': 'D'},
    {'label': 'Influencer', 'value': 'I'},
    {'label': 'Steady', 'value': 'S'},
    {'label': 'Conscientious', 'value': 'C'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _promptController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final apiClient = ref.read(apiClientProvider);

      // Load metadata in parallel
      final [templates, traits, contexts] = await Future.wait([
        apiClient.getPersonalityTemplates(),
        apiClient.getTraitSets(),
        apiClient.getScenarioContexts(),
      ]);

      _personalityTemplates = templates as List<PersonalityTemplate>;
      _traitSets = traits as List<TraitSet>;
      _scenarioContexts = contexts as List<ScenarioContext>;

      // If editing, load the full scenario detail
      if (widget.scenario != null) {
        _fullScenario = await apiClient.getScenarioDetail(widget.scenario!.id);

        _titleController.text = _fullScenario!.title;
        _promptController.text = _fullScenario!.aiSystemPrompt;
        _selectedDiscType = _fullScenario!.discType;
        _selectedVisibility = _fullScenario!.visibility;
        _selectedPersonalityTemplateId = _fullScenario!.personalityTemplateId;
        _selectedTraitSetId = _fullScenario!.traitSetId;
        _selectedScenarioContextId = _fullScenario!.scenarioContextId;

        _objectives = _fullScenario!.objectives
            .map((o) => {
                  'label': o.label,
                  'description': o.description ?? '',
                  'max_points': o.maxPoints,
                })
            .toList();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadError = 'Error loading form data: $e';
      });
    }
  }

  void _addObjective() {
    setState(() {
      _objectives.add({
        'label': '',
        'description': '',
        'max_points': 10,
      });
    });
  }

  void _removeObjective(int index) {
    setState(() {
      _objectives.removeAt(index);
    });
  }

  void _updateObjective(int index, String field, dynamic value) {
    setState(() {
      _objectives[index][field] = value;
    });
  }

  Color _getDiscColor(String disc) {
    switch (disc.toUpperCase()) {
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


  Future<void> _saveScenario() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scenario title is required')),
      );
      return;
    }

    if (_promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI system prompt is required')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final apiClient = ref.read(apiClientProvider);

      final objectivesData = _objectives
          .map((o) => {
                'label': o['label'],
                'description': o['description'],
                'max_points': o['max_points'],
              })
          .toList();

      if (widget.scenario != null) {
        // Edit mode
        await apiClient.updateScenario(
          scenarioId: widget.scenario!.id,
          title: _titleController.text.trim(),
          discType: _selectedDiscType,
          aiSystemPrompt: _promptController.text.trim(),
          visibility: _selectedVisibility,
          personalityTemplateId: _selectedPersonalityTemplateId,
          traitSetId: _selectedTraitSetId,
          scenarioContextId: _selectedScenarioContextId,
          objectives: objectivesData,
        );
      } else {
        // Create mode
        await apiClient.createScenario(
          title: _titleController.text.trim(),
          discType: _selectedDiscType,
          aiSystemPrompt: _promptController.text.trim(),
          visibility: _selectedVisibility,
          personalityTemplateId: _selectedPersonalityTemplateId,
          traitSetId: _selectedTraitSetId,
          scenarioContextId: _selectedScenarioContextId,
          objectives: objectivesData,
        );
      }

      // Refresh the scenarios list and navigate back
      ref.invalidate(scenariosProvider);

      if (mounted) {
        context.go('/manage-scenarios');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.scenario != null
                  ? 'Scenario updated successfully!'
                  : 'Scenario created successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving scenario: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.scenario != null ? 'Edit Scenario' : 'Create Scenario'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.scenario != null ? 'Edit Scenario' : 'Create Scenario'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_loadError!),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadData();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scenario != null ? 'Edit Scenario' : 'Create Scenario'),
        leading: BackButton(onPressed: () => context.go('/manage-scenarios')),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveScenario,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isSaving ? 'Saving...' : 'Save'),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Basic Info Card =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Training Scenario',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Basic details agents will see when choosing a scenario',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 16),
                    // Title field
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Scenario Title',
                        hintText: 'e.g., Motivated First-Time Buyer at Open House',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    // DISC Type Selector
                    Text(
                      'Client\'s DISC Profile',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.2,
                      children: _discOptions.map((opt) {
                        final isSelected = _selectedDiscType == opt['value'];
                        return InkWell(
                          onTap: () => setState(() => _selectedDiscType = opt['value']!),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _getDiscColor(opt['value']!)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? _getDiscColor(opt['value']!)
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  opt['value']!,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  opt['label']!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Visibility dropdown
                    Text(
                      'Visibility',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedVisibility,
                      items: [
                        const DropdownMenuItem(
                          value: 'personal',
                          child: Text('Personal (Only me)'),
                        ),
                        const DropdownMenuItem(
                          value: 'org',
                          child: Text('Organization (Org members)'),
                        ),
                        const DropdownMenuItem(
                          value: 'public',
                          child: Text('Public (Everyone)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedVisibility = value);
                        }
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ===== AI Instructions Card =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Client Instructions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The AI plays the client. These instructions are hidden from the agent.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _promptController,
                      decoration: InputDecoration(
                        labelText: 'System Prompt',
                        hintText:
                            'You are [Client Name], a [occupation] looking to [buy/sell]...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      maxLines: 8,
                      minLines: 8,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_promptController.text.length} characters',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ===== Client Background Card =====
            if (_personalityTemplates != null && _personalityTemplates!.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Client Background',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Who the AI is playing — occupation, motivations & red flags',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int?>(
                      initialValue: _selectedPersonalityTemplateId,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('— Select template —'),
                          ),
                          ..._personalityTemplates!.map((t) =>
                              DropdownMenuItem(
                                value: t.id,
                                child: Text(
                                  '${t.occupation} (${t.transactionType})',
                                ),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedPersonalityTemplateId = value);
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      if (_selectedPersonalityTemplateId != null)
                        _buildTemplatePreview(),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // ===== Trait Set Card =====
            if (_traitSets != null && _traitSets!.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Client Personality Traits',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Behavioral traits the AI exhibits',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int?>(
                        initialValue: _selectedTraitSetId,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('— Select trait set —'),
                          ),
                          ..._traitSets!.map((t) => DropdownMenuItem(
                                value: t.id,
                                child: Text(
                                    'Set #${t.traitSetNumber}: ${t.trait1}, ${t.trait2}, ${t.trait3}'),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedTraitSetId = value);
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      if (_selectedTraitSetId != null)
                        _buildTraitSetPreview(),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // ===== Scenario Context Card =====
            if (_scenarioContexts != null && _scenarioContexts!.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meeting Type',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The type of real estate interaction',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int?>(
                      initialValue: _selectedScenarioContextId,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('— Select context —'),
                          ),
                          ..._scenarioContexts!.map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedScenarioContextId = value);
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // ===== Objectives Card =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Scoring Objectives',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addObjective,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'What the agent must accomplish',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (_objectives.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No objectives yet — add skills the agent must demonstrate',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _objectives.length,
                        itemBuilder: (context, index) {
                          final obj = _objectives[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          decoration: InputDecoration(
                                            labelText: 'Objective Label',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                          onChanged: (value) =>
                                              _updateObjective(index, 'label', value),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 80,
                                        child: TextField(
                                          decoration: InputDecoration(
                                            labelText: 'Max Points',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) =>
                                              _updateObjective(
                                                index,
                                                'max_points',
                                                int.tryParse(value) ?? 10,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () => _removeObjective(index),
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        iconSize: 20,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    decoration: InputDecoration(
                                      labelText: 'Description',
                                      hintText:
                                          'e.g., Agent asked for a specific date and time...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                    ),
                                    minLines: 2,
                                    maxLines: 3,
                                    onChanged: (value) =>
                                        _updateObjective(index, 'description', value),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    if (_objectives.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Total max points: ${_objectives.fold<int>(0, (sum, o) => sum + (o['max_points'] as int? ?? 0))}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatePreview() {
    final template = _personalityTemplates
        ?.firstWhere((t) => t.id == _selectedPersonalityTemplateId);
    if (template == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (template.surfaceMotivation != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Surface motivation: ',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: template.surfaceMotivation,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            if (template.hiddenMotivation != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Hidden motivation: ',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: template.hiddenMotivation,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            if (template.timeframe != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Timeframe: ',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: template.timeframe,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            if (template.redFlags != null)
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Red flags: ',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: template.redFlags,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTraitSetPreview() {
    final traitSet = _traitSets?.firstWhere((t) => t.id == _selectedTraitSetId);
    if (traitSet == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        children: [
          Chip(label: Text(traitSet.trait1)),
          Chip(label: Text(traitSet.trait2)),
          Chip(label: Text(traitSet.trait3)),
        ],
      ),
    );
  }
}

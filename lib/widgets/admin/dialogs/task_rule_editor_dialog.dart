import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../models/task_definition.dart';
import '../../../models/task_rule.dart';
import '../../../theme/crud_modal_theme.dart';

/// Dialog for creating a new task rule.
/// 
/// Task rules define when tasks should be automatically added to cleaning
/// profiles based on conditions.
class TaskRuleEditorDialog extends StatefulWidget {
  const TaskRuleEditorDialog({super.key, required this.taskDefinitions});

  final List<TaskDefinition> taskDefinitions;

  @override
  State<TaskRuleEditorDialog> createState() => _TaskRuleEditorDialogState();
}

class _TaskRuleEditorDialogState extends State<TaskRuleEditorDialog> {
  late final TextEditingController _appliesWhen;
  late final TextEditingController _displayOrder;
  late final TextEditingController _notesTemplate;
  bool _required = true;
  int? _selectedTaskDefinitionId;

  @override
  void initState() {
    super.initState();
    _appliesWhen = TextEditingController(text: '{}');
    _displayOrder = TextEditingController();
    _notesTemplate = TextEditingController();
    _selectedTaskDefinitionId = int.tryParse(widget.taskDefinitions.first.id);
  }

  @override
  void dispose() {
    _appliesWhen.dispose();
    _displayOrder.dispose();
    _notesTemplate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildCrudModalTheme(context),
      child: AlertDialog(
        title: const Text('Create Task Rule'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _selectedTaskDefinitionId,
                  decoration: const InputDecoration(
                    labelText: 'Task Definition',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.taskDefinitions
                      .map(
                        (task) => DropdownMenuItem<int>(
                          value: int.tryParse(task.id),
                          child: Text('${task.code} • ${task.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedTaskDefinitionId = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _appliesWhen,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Applies When JSON',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _displayOrder,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Display Order (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesTemplate,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes Template (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _required,
                  title: const Text('Required'),
                  onChanged: (value) =>
                      setState(() => _required = value == true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (_selectedTaskDefinitionId == null) return;
              final applies = _parseAppliesWhen(_appliesWhen.text);
              if (applies == null) return;
              Navigator.pop(
                context,
                TaskRuleCreateInput(
                  taskDefinitionId: _selectedTaskDefinitionId!,
                  appliesWhen: applies,
                  required: _required,
                  displayOrder: int.tryParse(_displayOrder.text.trim()),
                  notesTemplate: _notesTemplate.text.trim().isEmpty
                      ? null
                      : _notesTemplate.text.trim(),
                ),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _parseAppliesWhen(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return {};
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

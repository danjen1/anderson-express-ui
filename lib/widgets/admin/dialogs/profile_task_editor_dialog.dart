import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../models/task_definition.dart';
import '../../../models/profile_task.dart';

class ProfileTaskEditorDialog extends StatefulWidget {
  const ProfileTaskEditorDialog({
    super.key,
    required this.taskDefinitions,
    this.isCreate = true,
    this.selectedTaskDefinitionId,
    this.requiredValue = true,
    this.displayOrderValue,
    this.taskMetadataValue = const {},
  });

  final List<TaskDefinition> taskDefinitions;
  final bool isCreate;
  final int? selectedTaskDefinitionId;
  final bool requiredValue;
  final int? displayOrderValue;
  final Map<String, dynamic> taskMetadataValue;

  @override
  State<ProfileTaskEditorDialog> createState() =>
      _ProfileTaskEditorDialogState();
}

class _ProfileTaskEditorDialogState extends State<ProfileTaskEditorDialog> {
  late final TextEditingController _displayOrder;
  late final TextEditingController _taskMetadata;
  late bool _required;
  int? _selectedTaskDefinitionId;

  @override
  void initState() {
    super.initState();
    _displayOrder = TextEditingController(
      text: widget.displayOrderValue?.toString() ?? '',
    );
    _taskMetadata = TextEditingController(
      text: widget.taskMetadataValue.isEmpty
          ? '{}'
          : jsonEncode(widget.taskMetadataValue),
    );
    _required = widget.requiredValue;
    _selectedTaskDefinitionId =
        widget.selectedTaskDefinitionId ??
        int.tryParse(widget.taskDefinitions.first.id);
  }

  @override
  void dispose() {
    _displayOrder.dispose();
    _taskMetadata.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isCreate ? 'Link Profile Task' : 'Edit Profile Task'),
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
                onChanged: widget.isCreate
                    ? (value) =>
                          setState(() => _selectedTaskDefinitionId = value)
                    : null,
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
                controller: _taskMetadata,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Task Metadata JSON',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _required,
                title: const Text('Required'),
                onChanged: (value) => setState(() => _required = value ?? true),
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
            final metadata = _parseMetadata(_taskMetadata.text);
            if (metadata == null) return;
            if (widget.isCreate) {
              if (_selectedTaskDefinitionId == null) return;
              Navigator.pop(
                context,
                ProfileTaskCreateInput(
                  taskDefinitionId: _selectedTaskDefinitionId!,
                  required: _required,
                  displayOrder: int.tryParse(_displayOrder.text.trim()),
                  taskMetadata: metadata,
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              ProfileTaskUpdateInput(
                required: _required,
                displayOrder: int.tryParse(_displayOrder.text.trim()),
                taskMetadata: metadata,
              ),
            );
          },
          child: Text(widget.isCreate ? 'Link' : 'Save'),
        ),
      ],
    );
  }

  Map<String, dynamic>? _parseMetadata(String raw) {
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

import 'package:flutter/material.dart';

import '../../../models/task_definition.dart';
import '../../../theme/crud_modal_theme.dart';

/// Dialog for creating a new task definition.
/// 
/// Task definitions are used to define standard cleaning tasks that can be
/// added to cleaning profiles.
class TaskDefinitionEditorDialog extends StatefulWidget {
  const TaskDefinitionEditorDialog({super.key});

  @override
  State<TaskDefinitionEditorDialog> createState() =>
      _TaskDefinitionEditorDialogState();
}

class _TaskDefinitionEditorDialogState
    extends State<TaskDefinitionEditorDialog> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController();
    _name = TextEditingController();
    _category = TextEditingController();
    _description = TextEditingController();
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _category.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildCrudModalTheme(context),
      child: AlertDialog(
        title: const Text('Create Task Definition'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: 'Code (e.g., DUST)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
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
              final code = _code.text.trim();
              final name = _name.text.trim();
              if (code.isEmpty || name.isEmpty) return;
              Navigator.pop(
                context,
                TaskDefinitionCreateInput(
                  code: code,
                  name: name,
                  category: _category.text.trim(),
                  description: _description.text.trim().isEmpty
                      ? null
                      : _description.text.trim(),
                ),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

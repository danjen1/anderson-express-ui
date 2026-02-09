import 'package:flutter/material.dart';
import '../../../models/location.dart';
import '../../../models/cleaning_profile.dart';
import '../../../theme/crud_modal_theme.dart';

class CleaningProfileEditorDialog extends StatefulWidget {
  const CleaningProfileEditorDialog({
    super.key,
    required this.locations,
    this.isCreate = true,
    this.selectedLocationId,
    this.name = '',
    this.notes = '',
  });

  final List<Location> locations;
  final bool isCreate;
  final int? selectedLocationId;
  final String name;
  final String notes;

  @override
  State<CleaningProfileEditorDialog> createState() =>
      _CleaningProfileEditorDialogState();
}

class _CleaningProfileEditorDialogState
    extends State<CleaningProfileEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  int? _selectedLocationId;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _notes = TextEditingController(text: widget.notes);
    _selectedLocationId =
        widget.selectedLocationId ?? int.tryParse(widget.locations.first.id);
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildCrudModalTheme(context),
      child: AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.isCreate
                    ? 'Create Cleaning Profile'
                    : 'Edit Cleaning Profile',
                style: TextStyle(
                  color: crudModalTitleColor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'assets/images/logo.png',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _selectedLocationId,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.locations
                      .map(
                        (location) => DropdownMenuItem<int>(
                          value: int.tryParse(location.id),
                          child: Text(location.locationNumber),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedLocationId = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Profile Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
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
              if (_selectedLocationId == null || _name.text.trim().isEmpty) {
                return;
              }
              if (widget.isCreate) {
                Navigator.pop(
                  context,
                  CleaningProfileCreateInput(
                    locationId: _selectedLocationId!,
                    name: _name.text.trim(),
                    notes: _notes.text.trim().isEmpty
                        ? null
                        : _notes.text.trim(),
                  ),
                );
              } else {
                Navigator.pop(
                  context,
                  CleaningProfileUpdateInput(
                    locationId: _selectedLocationId!,
                    name: _name.text.trim(),
                    notes: _notes.text.trim().isEmpty
                        ? null
                        : _notes.text.trim(),
                  ),
                );
              }
            },
            child: Text(widget.isCreate ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }
}

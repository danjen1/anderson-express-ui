import 'package:flutter/material.dart';
import '../../../models/client.dart';
import '../../../models/employee.dart';
import '../../../models/location.dart';
import '../../../theme/crud_modal_theme.dart';
import '../../../widgets/duration_picker_fields.dart';

class JobEditorDialog extends StatefulWidget {
  const JobEditorDialog({
    required this.isCreate,
    required this.clients,
    required this.locations,
    required this.cleaners,
    this.initialClientId,
    this.initialLocationId,
    this.initialScheduledDate,
    this.initialScheduledStartAt,
    this.initialEstimatedDurationMinutes,
    this.initialActualDurationMinutes,
    this.initialCleanerEmployeeId,
    this.initialStatus,
  });

  final bool isCreate;
  final List<Client> clients;
  final List<Location> locations;
  final List<Employee> cleaners;
  final int? initialClientId;
  final int? initialLocationId;
  final DateTime? initialScheduledDate;
  final String? initialScheduledStartAt;
  final int? initialEstimatedDurationMinutes;
  final int? initialActualDurationMinutes;
  final String? initialCleanerEmployeeId;
  final String? initialStatus;

  @override
  State<JobEditorDialog> createState() => JobEditorDialogState();
}

class JobEditorDialogState extends State<JobEditorDialog> {
  int? _selectedClientId;
  int? _selectedLocationId;
  String? _selectedCleanerId;
  String? _formError;
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  int _estimatedHours = 2;
  int _estimatedMinutesStep = 0;
  bool _includeActualDuration = false;
  int _actualHours = 0;
  int _actualMinutesStep = 0;

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.initialClientId;
    _selectedLocationId = widget.initialLocationId;
    _selectedDate =
        widget.initialScheduledDate ??
        DateTime.now().add(const Duration(days: 1));
    final estimatedMinutes = widget.initialEstimatedDurationMinutes ?? 120;
    _estimatedHours = estimatedMinutes ~/ 60;
    _estimatedMinutesStep = estimatedMinutes % 60;
    if (!DurationPickerFields.quarterHourSteps.contains(
      _estimatedMinutesStep,
    )) {
      _estimatedMinutesStep = 0;
    }
    final actualMinutes = widget.initialActualDurationMinutes;
    if (actualMinutes != null && actualMinutes >= 0) {
      _includeActualDuration = true;
      _actualHours = actualMinutes ~/ 60;
      _actualMinutesStep = actualMinutes % 60;
      if (!DurationPickerFields.quarterHourSteps.contains(_actualMinutesStep)) {
        _actualMinutesStep = 0;
      }
    }
    _selectedCleanerId = widget.initialCleanerEmployeeId;
    final cleanerExists = widget.cleaners.any(
      (cleaner) => cleaner.id == _selectedCleanerId,
    );
    if (!cleanerExists) {
      _selectedCleanerId = null;
    }
    final parsedStartAt = widget.initialScheduledStartAt == null
        ? null
        : DateTime.tryParse(widget.initialScheduledStartAt!);
    if (parsedStartAt != null) {
      final localStartAt = parsedStartAt.toLocal();
      _selectedTime = TimeOfDay(
        hour: localStartAt.hour,
        minute: localStartAt.minute,
      );
    }
    if (_selectedClientId == null && widget.clients.isNotEmpty) {
      final firstId = int.tryParse(widget.clients.first.id);
      if (firstId != null) {
        _selectedClientId = firstId;
      }
    }
    final clientExists = widget.clients.any(
      (client) => int.tryParse(client.id) == _selectedClientId,
    );
    if (!clientExists && widget.clients.isNotEmpty) {
      _selectedClientId = int.tryParse(widget.clients.first.id);
    }
    _syncLocationToClient();
  }

  List<Location> get _clientLocations {
    final selectedClientId = _selectedClientId;
    if (selectedClientId == null) return const [];
    return widget.locations
        .where((location) => location.clientId == selectedClientId)
        .toList();
  }

  void _syncLocationToClient() {
    final locations = _clientLocations;
    final selectedLocationId = _selectedLocationId;
    final hasSelected = locations.any(
      (location) => int.tryParse(location.id) == selectedLocationId,
    );
    if (!hasSelected) {
      if (locations.isEmpty) {
        _selectedLocationId = null;
      } else {
        _selectedLocationId = int.tryParse(locations.first.id);
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked == null) return;
    setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    final clientId = _selectedClientId;
    final locationId = _selectedLocationId;
    final estimatedDuration = (_estimatedHours * 60) + _estimatedMinutesStep;
    final actualDuration = _includeActualDuration
        ? ((_actualHours * 60) + _actualMinutesStep)
        : null;
    final initialStatus = widget.initialStatus?.trim().toLowerCase();
    if (initialStatus == 'completed' && _selectedCleanerId == null) {
      setState(() {
        _formError =
            'Completed jobs must remain assigned to a cleaner (cannot be set to None).';
      });
      return;
    }
    if (clientId == null || locationId == null || estimatedDuration <= 0) {
      setState(() {
        _formError =
            'Complete all required fields (date, client, location, estimated duration).';
      });
      return;
    }
    final selectedHour = _selectedTime.hour;
    if (selectedHour < 5 || selectedHour >= 21) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => Theme(
          data: buildCrudModalTheme(context),
          child: AlertDialog(
            title: Text(
              'Confirm late/early job time',
              style: TextStyle(
                color: crudModalTitleColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
            content: const Text(
              'This job is scheduled outside normal hours (5:00 AM - 9:00 PM). Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;

    Navigator.pop(
      context,
      JobEditorFormData(
        clientId: clientId,
        locationId: locationId,
        scheduledDate:
            '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
        scheduledStartAt: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        ).toUtc().toIso8601String(),
        scheduledTime: _selectedTime,
        estimatedDurationMinutes: estimatedDuration,
        actualDurationMinutes: actualDuration,
        cleanerEmployeeId: _selectedCleanerId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final clientLocations = _clientLocations;
    return Theme(
      data: buildCrudModalTheme(context),
      child: AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.isCreate ? 'Create Job' : 'Edit Job',
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '* Required fields',
                    style: TextStyle(
                      color: crudModalRequiredColor(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          'Date *: ${_selectedDate.month}-${_selectedDate.day}-${_selectedDate.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time),
                        label: Text('Time: ${_selectedTime.format(context)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _selectedClientId,
                  decoration: const InputDecoration(
                    labelText: 'Client *',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.clients
                      .map((client) {
                        final clientId = int.tryParse(client.id);
                        if (clientId == null) return null;
                        return DropdownMenuItem<int>(
                          value: clientId,
                          child: Text(client.name),
                        );
                      })
                      .whereType<DropdownMenuItem<int>>()
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedClientId = value;
                      _syncLocationToClient();
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _selectedLocationId,
                  decoration: const InputDecoration(
                    labelText: 'Location *',
                    border: OutlineInputBorder(),
                  ),
                  items: clientLocations
                      .map((location) {
                        final locationId = int.tryParse(location.id);
                        if (locationId == null) return null;
                        final line = location.address?.trim().isNotEmpty == true
                            ? location.address!.trim()
                            : location.locationNumber;
                        return DropdownMenuItem<int>(
                          value: locationId,
                          child: Text(line),
                        );
                      })
                      .whereType<DropdownMenuItem<int>>()
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedLocationId = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedCleanerId,
                  decoration: const InputDecoration(
                    labelText: 'Cleaner',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None (Pending)'),
                    ),
                    ...widget.cleaners.map(
                      (cleaner) => DropdownMenuItem<String?>(
                        value: cleaner.id,
                        child: Text(cleaner.name),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedCleanerId = value),
                ),
                const SizedBox(height: 10),
                DurationPickerFields(
                  label: 'Estimated Duration *',
                  hours: _estimatedHours,
                  minutesStep: _estimatedMinutesStep,
                  onHoursChanged: (value) =>
                      setState(() => _estimatedHours = value),
                  onMinutesChanged: (value) =>
                      setState(() => _estimatedMinutesStep = value),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include Actual Duration'),
                  value: _includeActualDuration,
                  onChanged: (value) =>
                      setState(() => _includeActualDuration = value),
                ),
                if (_includeActualDuration)
                  DurationPickerFields(
                    label: 'Actual Duration',
                    hours: _actualHours,
                    minutesStep: _actualMinutesStep,
                    onHoursChanged: (value) =>
                        setState(() => _actualHours = value),
                    onMinutesChanged: (value) =>
                        setState(() => _actualMinutesStep = value),
                  ),
                if (_formError != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formError!,
                      style: TextStyle(
                        color: dark
                            ? const Color(0xFFFFC1CC)
                            : const Color(0xFFE63721),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
            onPressed: _submit,
            child: Text(widget.isCreate ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class JobEditorFormData {
  const JobEditorFormData({
    required this.clientId,
    required this.locationId,
    required this.scheduledDate,
    required this.scheduledStartAt,
    required this.scheduledTime,
    required this.estimatedDurationMinutes,
    this.actualDurationMinutes,
    this.cleanerEmployeeId,
  });

  final int clientId;
  final int locationId;
  final String scheduledDate;
  final String scheduledStartAt;
  final TimeOfDay scheduledTime;
  final int estimatedDurationMinutes;
  final int? actualDurationMinutes;
  final String? cleanerEmployeeId;
}




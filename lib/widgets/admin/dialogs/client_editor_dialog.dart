import 'package:flutter/material.dart';
import '../../../models/client.dart';
import '../../../theme/crud_modal_theme.dart';

class ClientEditorDialog extends StatefulWidget {
  const ClientEditorDialog({
    super.key,
    this.name = '',
    this.status = 'active',
    this.email = '',
    this.phoneNumber = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.preferredContactMethod = '',
    this.preferredContactWindow = '',
    this.isCreate = true,
  });

  final String name;
  final String status;
  final String email;
  final String phoneNumber;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String preferredContactMethod;
  final String preferredContactWindow;
  final bool isCreate;

  @override
  State<ClientEditorDialog> createState() => _ClientEditorDialogState();
}

class _ClientEditorDialogState extends State<ClientEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zipCode;
  late final TextEditingController _preferredContactWindow;
  late String _preferredContactMethod;
  late String _status;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _email = TextEditingController(text: widget.email);
    _phone = TextEditingController(text: widget.phoneNumber);
    _address = TextEditingController(text: widget.address);
    _city = TextEditingController(text: widget.city);
    _state = TextEditingController(text: widget.state);
    _zipCode = TextEditingController(text: widget.zipCode);
    _preferredContactWindow = TextEditingController(
      text: widget.preferredContactWindow,
    );
    _preferredContactMethod = widget.preferredContactMethod.trim().isEmpty
        ? 'phone'
        : widget.preferredContactMethod.trim().toLowerCase();
    _status = widget.status.trim().isEmpty
        ? 'active'
        : widget.status.trim().toLowerCase();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zipCode.dispose();
    _preferredContactWindow.dispose();
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
                widget.isCreate ? 'Create Client' : 'Edit Client',
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
          width: 480,
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
                _field(_name, 'Name', required: true),
                const SizedBox(height: 10),
                _field(_email, 'Email', required: true),
                const SizedBox(height: 10),
                _field(_phone, 'Phone'),
                const SizedBox(height: 10),
                _field(_address, 'Address'),
                const SizedBox(height: 10),
                _field(_city, 'City'),
                const SizedBox(height: 10),
                _field(_state, 'State'),
                const SizedBox(height: 10),
                _field(_zipCode, 'Zip Code'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'invited', child: Text('Invited')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                    DropdownMenuItem(value: 'deleted', child: Text('Deleted')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _status = value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _preferredContactMethod,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Contact Method',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'phone', child: Text('Phone')),
                    DropdownMenuItem(value: 'email', child: Text('Email')),
                    DropdownMenuItem(value: 'sms', child: Text('SMS')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _preferredContactMethod = value);
                  },
                ),
                const SizedBox(height: 10),
                _field(_preferredContactWindow, 'Preferred Contact Window'),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2F313A)
                        : const Color(0xFFEAF4FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF4A4D5A)
                          : const Color(0xFFA8D6F7),
                    ),
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
              if (widget.isCreate) {
                if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                  context,
                  ClientCreateInput(
                    name: _name.text.trim(),
                    email: _email.text.trim(),
                    status: _status,
                    phoneNumber: _nullable(_phone.text),
                    address: _nullable(_address.text),
                    city: _nullable(_city.text),
                    state: _nullable(_state.text),
                    zipCode: _nullable(_zipCode.text),
                    preferredContactMethod: _nullable(_preferredContactMethod),
                    preferredContactWindow: _nullable(
                      _preferredContactWindow.text,
                    ),
                  ),
                );
              } else {
                Navigator.pop(
                  context,
                  ClientUpdateInput(
                    name: _nullable(_name.text),
                    email: _nullable(_email.text),
                    status: _status,
                    phoneNumber: _nullable(_phone.text),
                    address: _nullable(_address.text),
                    city: _nullable(_city.text),
                    state: _nullable(_state.text),
                    zipCode: _nullable(_zipCode.text),
                    preferredContactMethod: _nullable(_preferredContactMethod),
                    preferredContactWindow: _nullable(
                      _preferredContactWindow.text,
                    ),
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

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

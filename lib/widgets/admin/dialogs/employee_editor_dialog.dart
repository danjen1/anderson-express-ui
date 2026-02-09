import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../models/employee.dart';
import '../../../theme/crud_modal_theme.dart';

class EmployeeEditorDialog extends StatefulWidget {
  const EmployeeEditorDialog({
    this.employeeToEdit,
    this.onDelete,
    this.employeeNumber = '',
    this.status = 'invited',
    this.name = '',
    this.email = '',
    this.phoneNumber = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.photoUrl = '',
    this.isCreate = true,
  });

  final dynamic employeeToEdit;
  final VoidCallback? onDelete;
  final String employeeNumber;
  final String status;
  final String name;
  final String email;
  final String phoneNumber;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String photoUrl;
  final bool isCreate;

  @override
  State<EmployeeEditorDialog> createState() => EmployeeEditorDialogState();
}

class EmployeeEditorDialogState extends State<EmployeeEditorDialog> {
  static const String _defaultEmployeePhotoAsset =
      '/assets/images/profiles/employee_default.png';
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zipCode;
  late final TextEditingController _photoUrl;
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
    _photoUrl = TextEditingController(text: widget.photoUrl);
    _status = widget.status.trim().isEmpty
        ? 'invited'
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
    _photoUrl.dispose();
    super.dispose();
  }

  String _assetPath(String value) {
    return value.startsWith('/') ? value.substring(1) : value;
  }

  ImageProvider _photoProvider(String? value, {required String fallback}) {
    final candidate = value?.trim() ?? '';
    if (candidate.isEmpty) {
      return AssetImage(_assetPath(fallback));
    }
    if (candidate.startsWith('data:image/')) {
      final comma = candidate.indexOf(',');
      if (comma > 0 && comma < candidate.length - 1) {
        try {
          return MemoryImage(base64Decode(candidate.substring(comma + 1)));
        } catch (_) {}
      }
      return AssetImage(_assetPath(fallback));
    }
    if (candidate.startsWith('/assets/')) {
      return AssetImage(_assetPath(candidate));
    }
    if (candidate.startsWith('http://') || candidate.startsWith('https://')) {
      return NetworkImage(candidate);
    }
    return AssetImage(_assetPath(fallback));
  }

  Future<void> _pickPhotoFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;
    if (bytes.length > 500 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image must be under 500KB. Please choose a smaller file.',
          ),
        ),
      );
      return;
    }

    final ext = (file.extension ?? '').toLowerCase();
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    setState(() => _photoUrl.text = dataUrl);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: buildCrudModalTheme(context),
      child: AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.isCreate ? 'Create Employee' : 'Edit Employee',
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
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _photoUrl,
                  builder: (context, value, _) {
                    final path = value.text.trim().isNotEmpty
                        ? value.text.trim()
                        : _defaultEmployeePhotoAsset;
                    return Stack(
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: dark
                              ? const Color(0xFF3B4250)
                              : const Color(0xFFA8D6F7),
                          backgroundImage: _photoProvider(
                            path,
                            fallback: _defaultEmployeePhotoAsset,
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Upload profile photo',
                            onPressed: _pickPhotoFile,
                            icon: const Icon(Icons.edit, size: 18),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '* Required fields',
                      style: TextStyle(
                        color: crudModalRequiredColor(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Employee #: ${widget.employeeNumber.isEmpty ? '—' : widget.employeeNumber}',
                      style: TextStyle(
                        color: crudModalTitleColor(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
                    DropdownMenuItem(value: 'invited', child: Text('Invited')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                    DropdownMenuItem(
                      value: 'resigned',
                      child: Text('Resigned'),
                    ),
                    DropdownMenuItem(value: 'deleted', child: Text('Deleted')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _status = value);
                  },
                ),
                // if (widget.isCreate)
                //   Padding(
                //     padding: const EdgeInsets.only(top: 8),
                //     child: Align(
                //       alignment: Alignment.centerLeft,
                //       child: Text(
                //         'New employees default to the shared profile image unless changed above.',
                //         style: TextStyle(
                //           fontSize: 12,
                //           color: dark
                //               ? const Color(0xFFE4E4E4)
                //               : const Color(0xFF296273),
                //         ),
                //       ),
                //     ),
                //   ),
              ],
            ),
          ),
        ),
        actions: [
          if (!widget.isCreate && widget.onDelete != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onDelete!();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
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
                  EmployeeCreateInput(
                    name: _name.text.trim(),
                    email: _email.text.trim(),
                    phoneNumber: _nullable(_phone.text),
                    address: _nullable(_address.text),
                    city: _nullable(_city.text),
                    state: _nullable(_state.text),
                    zipCode: _nullable(_zipCode.text),
                    photoUrl: _nullable(_photoUrl.text),
                    status: _status,
                  ),
                );
              } else {
                Navigator.pop(
                  context,
                  EmployeeUpdateInput(
                    name: _nullable(_name.text),
                    email: _nullable(_email.text),
                    phoneNumber: _nullable(_phone.text),
                    address: _nullable(_address.text),
                    city: _nullable(_city.text),
                    state: _nullable(_state.text),
                    zipCode: _nullable(_zipCode.text),
                    photoUrl: _nullable(_photoUrl.text),
                    status: _status,
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


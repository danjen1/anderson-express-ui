import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../models/client.dart';
import '../../../models/location.dart';
import '../../../theme/crud_modal_theme.dart';

class LocationEditorDialog extends StatefulWidget {
  const LocationEditorDialog({
    required this.clients,
    this.clientId,
    this.status = 'active',
    this.type = 'residential',
    this.photoUrl = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.isCreate = true,
  });

  final List<Client> clients;
  final int? clientId;
  final String status;
  final String type;
  final String photoUrl;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final bool isCreate;

  @override
  State<LocationEditorDialog> createState() => LocationEditorDialogState();
}

class LocationEditorDialogState extends State<LocationEditorDialog> {
  static const String _defaultLocationPhotoAsset =
      '/assets/images/locations/location_default.png';
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zipCode;
  late final TextEditingController _photoUrl;
  late String _type;
  late String _status;
  int? _selectedClientId;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: widget.address);
    _city = TextEditingController(text: widget.city);
    _state = TextEditingController(text: widget.state);
    _zipCode = TextEditingController(text: widget.zipCode);
    _photoUrl = TextEditingController(text: widget.photoUrl);
    _type = widget.type.toLowerCase();
    _status = widget.status.trim().isEmpty
        ? 'active'
        : widget.status.trim().toLowerCase();
    _selectedClientId =
        widget.clientId ??
        (widget.clients.isNotEmpty
            ? int.tryParse(widget.clients.first.id)
            : null);
  }

  @override
  void dispose() {
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
                widget.isCreate ? 'Create Location' : 'Edit Location',
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
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _photoUrl,
                  builder: (context, value, _) {
                    final path = value.text.trim().isNotEmpty
                        ? value.text.trim()
                        : _defaultLocationPhotoAsset;
                    return Stack(
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: dark
                              ? const Color(0xFF3B4250)
                              : const Color(0xFFA8D6F7),
                          backgroundImage: _photoProvider(
                            path,
                            fallback: _defaultLocationPhotoAsset,
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Upload location photo',
                            onPressed: _pickPhotoFile,
                            icon: const Icon(Icons.edit, size: 18),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
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
                if (widget.isCreate)
                  DropdownButtonFormField<int>(
                    initialValue: _selectedClientId,
                    decoration: const InputDecoration(
                      labelText: 'Client *',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.clients
                        .map(
                          (client) => DropdownMenuItem<int>(
                            value: int.tryParse(client.id),
                            child: Text(
                              '${client.clientNumber} • ${client.name}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedClientId = value),
                  ),
                if (widget.isCreate) const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'residential',
                      child: Text('Residential'),
                    ),
                    DropdownMenuItem(
                      value: 'commercial',
                      child: Text('Commercial'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _type = value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
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
                _field(_address, 'Address', required: true),
                const SizedBox(height: 10),
                _field(_city, 'City', required: true),
                const SizedBox(height: 10),
                _field(_state, 'State', required: true),
                const SizedBox(height: 10),
                _field(_zipCode, 'Zip Code', required: true),
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
                if (_selectedClientId == null) return;
                Navigator.pop(
                  context,
                  LocationCreateInput(
                    type: _type,
                    status: _status,
                    clientId: _selectedClientId!,
                    photoUrl: _nullable(_photoUrl.text),
                    address: _nullable(_address.text),
                    city: _nullable(_city.text),
                    state: _nullable(_state.text),
                    zipCode: _nullable(_zipCode.text),
                  ),
                );
              } else {
                Navigator.pop(
                  context,
                  LocationUpdateInput(
                    type: _type,
                    status: _status,
                    photoUrl: _nullable(_photoUrl.text),
                    address: _nullable(_address.text),
                    city: _nullable(_city.text),
                    state: _nullable(_state.text),
                    zipCode: _nullable(_zipCode.text),
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


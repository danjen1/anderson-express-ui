import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/client.dart';
import '../../../models/location.dart';
import '../../../theme/crud_modal_theme.dart';
import '../../../utils/photo_picker_utils.dart';
import '../../../utils/phone_formatter.dart';
import '../../../services/validation_service.dart';

class LocationEditorDialog extends StatefulWidget {
  const LocationEditorDialog({
    required this.clients,
    this.locationToEdit,
    this.onDelete,
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
  final dynamic locationToEdit;
  final VoidCallback? onDelete;
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
  static const List<String> usStates = [
    'AL',
    'AK',
    'AZ',
    'AR',
    'CA',
    'CO',
    'CT',
    'DE',
    'FL',
    'GA',
    'HI',
    'ID',
    'IL',
    'IN',
    'IA',
    'KS',
    'KY',
    'LA',
    'ME',
    'MD',
    'MA',
    'MI',
    'MN',
    'MS',
    'MO',
    'MT',
    'NE',
    'NV',
    'NH',
    'NJ',
    'NM',
    'NY',
    'NC',
    'ND',
    'OH',
    'OK',
    'OR',
    'PA',
    'RI',
    'SC',
    'SD',
    'TN',
    'TX',
    'UT',
    'VT',
    'VA',
    'WA',
    'WV',
    'WI',
    'WY',
  ];

  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _zipCode;
  late final TextEditingController _photoUrl;
  late String _type;
  late String _status;
  int? _selectedClientId;
  String? _selectedState;

  // For address validation
  bool _isValidatingAddress = false;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(); // Phone not supported in backend yet
    _address = TextEditingController(text: widget.address);
    _city = TextEditingController(text: widget.city);
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
    _selectedState = widget.state.trim().isEmpty
        ? null
        : widget.state.trim().toUpperCase();
  }

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    _city.dispose();
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
    final dataUrl = await showPhotoPickerDialog(
      context,
      title: 'Update Location Photo',
      message: 'Select a new photo for the location.',
    );
    if (dataUrl != null) {
      setState(() => _photoUrl.text = dataUrl);
    }
  }

  Future<bool> _validateAddress() async {
    // Allow empty addresses
    if (_address.text.trim().isEmpty ||
        _city.text.trim().isEmpty ||
        _selectedState == null ||
        _zipCode.text.trim().isEmpty) {
      return true;
    }

    setState(() => _isValidatingAddress = true);

    try {
      final result = await ValidationService.validateAddress(
        address: _address.text,
        city: _city.text,
        state: _selectedState!,
        zipCode: _zipCode.text,
      );

      if (!mounted) return false;

      switch (result.status) {
        case AddressValidationStatus.valid:
          return true;

        case AddressValidationStatus.suggestion:
          final useSuggestion = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => Theme(
              data: buildCrudModalTheme(context),
              child: AlertDialog(
                title: const Text('Address Suggestion'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'We found a slightly different address:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You entered:\n${_address.text}, ${_city.text}, ${_selectedState}, ${_zipCode.text}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Found address:\n${result.suggestedStreet}, ${result.suggestedCity}, ${result.suggestedState}, ${result.suggestedZip}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Would you like to use the found address?',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Keep Mine'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Use Found'),
                  ),
                ],
              ),
            ),
          );

          if (useSuggestion == true) {
            setState(() {
              _address.text = result.suggestedStreet ?? _address.text;
              _city.text = result.suggestedCity ?? _city.text;
              _selectedState = result.suggestedState ?? _selectedState;
              _zipCode.text = result.suggestedZip ?? _zipCode.text;
            });
          }
          return true;

        case AddressValidationStatus.invalid:
          await showDialog(
            context: context,
            builder: (dialogContext) => Theme(
              data: buildCrudModalTheme(context),
              child: AlertDialog(
                title: const Text('Address Not Found'),
                content: const Text(
                  'We could not verify this address. Please check for typos.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          );
          return false;

        case AddressValidationStatus.incomplete:
          await showDialog(
            context: context,
            builder: (dialogContext) => Theme(
              data: buildCrudModalTheme(context),
              child: AlertDialog(
                title: const Text('Incomplete Address'),
                content: const Text(
                  'This address appears incomplete. Please ensure all fields are filled correctly.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          );
          return false;
      }
    } catch (e) {
      // Fail open on network errors
      return true;
    } finally {
      if (mounted) {
        setState(() => _isValidatingAddress = false);
      }
    }
  }

  Future<void> _submit() async {
    // Validate address first
    final addressValid = await _validateAddress();
    if (!addressValid) return;

    // Proceed with save
    _save();
  }

  void _save() {
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
          state: _selectedState,
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
          state: _selectedState,
          zipCode: _nullable(_zipCode.text),
        ),
      );
    }
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
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: dark
                                  ? const Color(0xFF657184)
                                  : const Color(0xFFBFDFF4),
                              width: 2.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 56,
                            backgroundColor: dark
                                ? const Color(0xFF3B4250)
                                : const Color(0xFFA8D6F7),
                            backgroundImage: _photoProvider(
                              path,
                              fallback: _defaultLocationPhotoAsset,
                            ),
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
                // Phone field (for future use)
                TextField(
                  controller: _phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [PhoneNumberFormatter()],
                ),
                const SizedBox(height: 10),
                _field(_address, 'Address', required: true),
                const SizedBox(height: 10),
                _field(_city, 'City', required: true),
                const SizedBox(height: 10),
                // State autocomplete with Zip on same row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Focus(
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.tab) {
                            final options = usStates.where((state) {
                              return state.toLowerCase().contains(
                                (_selectedState ?? '').toLowerCase(),
                              );
                            }).toList();
                            if (options.isNotEmpty) {
                              setState(() => _selectedState = options.first);
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Autocomplete<String>(
                          initialValue: TextEditingValue(
                            text: _selectedState ?? '',
                          ),
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return usStates;
                            }
                            return usStates.where((state) {
                              return state.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              );
                            });
                          },
                          onSelected: (String selection) {
                            setState(() => _selectedState = selection);
                          },
                          fieldViewBuilder:
                              (
                                context,
                                textEditingController,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                textEditingController.text =
                                    _selectedState ?? '';
                                textEditingController
                                    .selection = TextSelection.fromPosition(
                                  TextPosition(
                                    offset: textEditingController.text.length,
                                  ),
                                );
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'State *',
                                    border: OutlineInputBorder(),
                                  ),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  onChanged: (value) {
                                    final upper = value.toUpperCase();
                                    if (usStates.contains(upper)) {
                                      setState(() => _selectedState = upper);
                                    }
                                  },
                                );
                              },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: _field(_zipCode, 'Zip Code', required: true),
                    ),
                  ],
                ),
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
            onPressed: _isValidatingAddress ? null : _submit,
            child: _isValidatingAddress
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.isCreate ? 'Create' : 'Save'),
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

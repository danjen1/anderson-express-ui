import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/employee.dart';
import '../../../theme/crud_modal_theme.dart';
import '../../../utils/photo_picker_utils.dart';
import '../../../utils/phone_formatter.dart';
import '../../../services/validation_service.dart';

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
  late final TextEditingController _zipCode;
  late final TextEditingController _photoUrl;
  late String _status;
  String? _selectedState;

  // For email validation
  bool _isValidatingEmail = false;
  
  // For address validation
  bool _isValidatingAddress = false;

  static const List<String> usStates = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _email = TextEditingController(text: widget.email);
    // Format phone number if it exists
    final formattedPhone = widget.phoneNumber.isEmpty 
        ? '' 
        : formatPhoneNumber(widget.phoneNumber);
    _phone = TextEditingController(text: formattedPhone);
    _address = TextEditingController(text: widget.address);
    _city = TextEditingController(text: widget.city);
    _zipCode = TextEditingController(text: widget.zipCode);
    _photoUrl = TextEditingController(text: widget.photoUrl);
    _status = widget.status.trim().isEmpty
        ? 'invited'
        : widget.status.trim().toLowerCase();
    _selectedState = widget.state.trim().isEmpty ? null : widget.state.trim().toUpperCase();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
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
      title: 'Update Profile Photo',
      message: 'Select a new photo for the employee profile.',
    );
    if (dataUrl != null) {
      setState(() => _photoUrl.text = dataUrl);
    }
  }

  /// Validate email doesn't already exist in database
  Future<bool> _validateEmail() async {
    setState(() => _isValidatingEmail = true);
    
    try {
      final error = await ValidationService.validateEmailUniqueness(
        _email.text,
        currentEmail: widget.isCreate ? null : widget.email,
        checkEmployees: true,
        checkClients: true,
      );
      
      if (error != null) {
        if (!mounted) return false;
        
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => Theme(
            data: buildCrudModalTheme(context),
            child: AlertDialog(
              title: const Text('Email Already Exists'),
              content: Text(error),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        );
        return false;
      }
      
      return true;
    } finally {
      if (mounted) setState(() => _isValidatingEmail = false);
    }
  }

  /// Validate address and geocode
  Future<bool> _validateAddress() async {
    // Skip if address fields are empty
    if (_address.text.trim().isEmpty || 
        _city.text.trim().isEmpty || 
        _selectedState == null) {
      return true; // Allow empty addresses
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
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => Theme(
              data: buildCrudModalTheme(context),
              child: AlertDialog(
                title: const Text('Invalid Address'),
                content: const Text(
                  'We could not verify this address. Please check the street, city, and state.',
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          );
          return false;

        case AddressValidationStatus.incomplete:
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => Theme(
              data: buildCrudModalTheme(context),
              child: AlertDialog(
                title: const Text('Incomplete Address'),
                content: const Text(
                  'Please provide street, city, and state for address validation.',
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          );
          return false;
      }
    } finally {
      if (mounted) setState(() => _isValidatingAddress = false);
    }
  }

  Future<void> _submit() async {
    // Validate email
    if (!await _validateEmail()) return;
    
    // Validate address
    if (!await _validateAddress()) return;

    // All validation passed, return the result
    if (widget.isCreate) {
      if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
        return;
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        EmployeeCreateInput(
          name: _name.text.trim(),
          email: _email.text.trim(),
          phoneNumber: _nullable(_phone.text),
          address: _nullable(_address.text),
          city: _nullable(_city.text),
          state: _selectedState,
          zipCode: _nullable(_zipCode.text),
          photoUrl: _nullable(_photoUrl.text),
          status: _status,
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.pop(
        context,
        EmployeeUpdateInput(
          name: _nullable(_name.text),
          email: _nullable(_email.text),
          phoneNumber: _nullable(_phone.text),
          address: _nullable(_address.text),
          city: _nullable(_city.text),
          state: _selectedState,
          zipCode: _nullable(_zipCode.text),
          photoUrl: _nullable(_photoUrl.text),
          status: _status,
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
                              fallback: _defaultEmployeePhotoAsset,
                            ),
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
                TextField(
                  controller: _phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    hintText: '(555) 123-4567',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [PhoneNumberFormatter()],
                ),
                const SizedBox(height: 10),
                _field(_address, 'Address'),
                const SizedBox(height: 10),
                _field(_city, 'City'),
                const SizedBox(height: 10),
                // State and Zip on same row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Autocomplete<String>(
                        initialValue: _selectedState == null
                            ? const TextEditingValue()
                            : TextEditingValue(text: _selectedState!),
                        displayStringForOption: (String state) => state,
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return usStates;
                          }
                          final searchText = textEditingValue.text.toUpperCase();
                          return usStates.where((String state) {
                            return state.startsWith(searchText);
                          });
                        },
                        onSelected: (String state) {
                          setState(() => _selectedState = state);
                        },
                        fieldViewBuilder: (
                          BuildContext context,
                          TextEditingController controller,
                          FocusNode focusNode,
                          VoidCallback onFieldSubmitted,
                        ) {
                          return Focus(
                            onKeyEvent: (node, event) {
                              // Handle Tab key like Enter
                              if (event is KeyDownEvent && 
                                  event.logicalKey == LogicalKeyboardKey.tab) {
                                final upperValue = controller.text.toUpperCase();
                                final matchingState = usStates.firstWhere(
                                  (state) => state == upperValue || state.startsWith(upperValue),
                                  orElse: () => '',
                                );
                                if (matchingState.isNotEmpty) {
                                  setState(() => _selectedState = matchingState);
                                  controller.text = matchingState;
                                }
                                return KeyEventResult.ignored; // Allow tab to move focus
                              }
                              return KeyEventResult.ignored;
                            },
                            child: TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'State',
                                hintText: 'Type to search...',
                                border: OutlineInputBorder(),
                              ),
                              textCapitalization: TextCapitalization.characters,
                              onFieldSubmitted: (value) {
                                // When Enter is pressed, select the first matching state
                                final upperValue = value.toUpperCase();
                                final matchingState = usStates.firstWhere(
                                  (state) => state == upperValue || state.startsWith(upperValue),
                                  orElse: () => '',
                                );
                                if (matchingState.isNotEmpty) {
                                  setState(() => _selectedState = matchingState);
                                  controller.text = matchingState;
                                }
                                onFieldSubmitted();
                              },
                              onChanged: (value) {
                                // Only update if it's a valid state code
                                final upperValue = value.toUpperCase();
                                if (usStates.contains(upperValue)) {
                                  setState(() => _selectedState = upperValue);
                                } else if (value.isEmpty) {
                                  setState(() => _selectedState = null);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(_zipCode, 'Zip Code'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Only show status dropdown when editing
                if (!widget.isCreate)
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
                if (!widget.isCreate) const SizedBox(height: 10),
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
            onPressed: _isValidatingEmail || _isValidatingAddress ? null : _submit,
            child: _isValidatingEmail || _isValidatingAddress
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


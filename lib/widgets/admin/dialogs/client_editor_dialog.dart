import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/client.dart';
import '../../../theme/crud_modal_theme.dart';
import '../../../utils/phone_formatter.dart';
import '../../../services/validation_service.dart';

class ClientEditorDialog extends StatefulWidget {
  const ClientEditorDialog({
    super.key,
    this.clientToEdit,
    this.onDelete,
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
    this.serviceNotes = '',
    this.isCreate = true,
  });

  final dynamic clientToEdit;
  final VoidCallback? onDelete;
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
  final String serviceNotes;
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
  late final TextEditingController _zipCode;
  late final TextEditingController _preferredContactWindow;
  late final TextEditingController _serviceNotes;
  late String _preferredContactMethod;
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
    _preferredContactWindow = TextEditingController(
      text: widget.preferredContactWindow,
    );
    _serviceNotes = TextEditingController(text: widget.serviceNotes);
    _preferredContactMethod = widget.preferredContactMethod.trim().isEmpty
        ? 'phone'
        : widget.preferredContactMethod.trim().toLowerCase();
    // Always default to 'invited' for new clients, use provided status for edit
    _status = widget.isCreate 
        ? 'invited' 
        : (widget.status.trim().isEmpty ? 'active' : widget.status.trim().toLowerCase());
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
    _preferredContactWindow.dispose();
    _serviceNotes.dispose();
    super.dispose();
  }

  /// Validate email doesn't already exist in database
  Future<bool> _validateEmail() async {
    setState(() => _isValidatingEmail = true);
    
    try {
      final error = await ValidationService.validateEmailUniqueness(
        _email.text,
        currentEmail: widget.isCreate ? null : widget.email,
        checkClients: true,
        checkEmployees: false,
      );

      if (error != null && mounted) {
        await showDialog(
          context: context,
          builder: (dialogContext) => Theme(
            data: buildCrudModalTheme(context),
            child: AlertDialog(
              title: const Text('Email Already Exists'),
              content: Text(
                'A client with email "${_email.text.trim()}" already exists.\n\n'
                'Please use a different email address.',
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

      return true;
    } finally {
      if (mounted) {
        setState(() => _isValidatingEmail = false);
      }
    }
  }

  /// Validate address can be geocoded (for billing accuracy)
  Future<bool> _validateAddress() async {
    setState(() => _isValidatingAddress = true);

    try {
      final result = await ValidationService.validateAddress(
        address: _address.text,
        city: _city.text,
        state: _selectedState,
        zipCode: _zipCode.text,
      );

      if (!mounted) return false;

      switch (result.status) {
        case AddressValidationStatus.valid:
          // Address is valid (or no address provided)
          return true;

        case AddressValidationStatus.suggestion:
          // Geocoded address differs from entered - show suggestion
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
                      'We found a similar address:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text('You entered:'),
                    Text(
                      result.enteredAddress ?? '',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Suggested:'),
                    Text(
                      result.suggestedAddress ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Would you like to use the suggested address?',
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
                    child: const Text('Use Suggested'),
                  ),
                ],
              ),
            ),
          );

          if (useSuggestion == true) {
            // Update form fields with suggested address
            setState(() {
              if (result.suggestedStreet != null) {
                _address.text = result.suggestedStreet!;
              }
              if (result.suggestedCity != null) {
                _city.text = result.suggestedCity!;
              }
              if (result.suggestedState != null) {
                _selectedState = result.suggestedState;
              }
              if (result.suggestedZip != null) {
                _zipCode.text = result.suggestedZip!;
              }
            });
            return true;
          } else {
            // User wants to keep their version - allow it
            return true;
          }

        case AddressValidationStatus.invalid:
          // Address could not be verified
          await showDialog(
            context: context,
            builder: (dialogContext) => Theme(
              data: buildCrudModalTheme(context),
              child: AlertDialog(
                title: const Text('Invalid Address'),
                content: Text(result.message ?? 'Unable to verify address'),
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
          // Partial address provided
          await showDialog(
            context: context,
            builder: (dialogContext) => Theme(
              data: buildCrudModalTheme(context),
              child: AlertDialog(
                title: const Text('Incomplete Address'),
                content: Text(result.message ?? 'Please complete the address'),
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
    } finally {
      if (mounted) {
        setState(() => _isValidatingAddress = false);
      }
    }
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final clientNumber = widget.clientToEdit?.clientNumber;
    
    return Theme(
      data: buildCrudModalTheme(context),
      child: AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
            if (clientNumber != null && clientNumber.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                clientNumber,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
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
                TextField(
                  controller: _phone,
                  inputFormatters: [PhoneNumberFormatter()],
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    hintText: '(555) 555-5555',
                    border: OutlineInputBorder(),
                  ),
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
                if (!widget.isCreate) const SizedBox(height: 10),
                TextFormField(
                  controller: _serviceNotes,
                  decoration: const InputDecoration(
                    labelText: 'Service Notes',
                    hintText: 'Enter any special requirements or notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  minLines: 2,
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
            onPressed: (_isValidatingEmail || _isValidatingAddress) ? null : () async {
              // Basic validation
              if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
                return;
              }

              // Validate email doesn't already exist
              final emailValid = await _validateEmail();
              if (!emailValid) return;

              // Validate address can be geocoded (for billing)
              final addressValid = await _validateAddress();
              if (!addressValid) return;

              // If all validations pass, return the data
              if (widget.isCreate) {
                if (!mounted) return;
                Navigator.pop(
                  context,
                  ClientCreateInput(
                    name: _name.text.trim(),
                    email: _email.text.trim(),
                    status: _status,
                    phoneNumber: _nullable(_phone.text),
                    address: _nullable(_address.text),
                    city: _nullable(_city.text),
                    state: _selectedState,
                    zipCode: _nullable(_zipCode.text),
                    preferredContactMethod: _nullable(_preferredContactMethod),
                    preferredContactWindow: _nullable(
                      _preferredContactWindow.text,
                    ),
                    serviceNotes: _nullable(_serviceNotes.text),
                  ),
                );
              } else {
                if (!mounted) return;
                Navigator.pop(
                  context,
                  ClientUpdateInput(
                    name: _nullable(_name.text),
                    email: _nullable(_email.text),
                    status: _status,
                    phoneNumber: _nullable(_phone.text),
                    address: _nullable(_address.text),
                    city: _nullable(_city.text),
                    state: _selectedState,
                    zipCode: _nullable(_zipCode.text),
                    preferredContactMethod: _nullable(_preferredContactMethod),
                    preferredContactWindow: _nullable(
                      _preferredContactWindow.text,
                    ),
                    serviceNotes: _nullable(_serviceNotes.text),
                  ),
                );
              }
            },
            child: (_isValidatingEmail || _isValidatingAddress)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(_isValidatingEmail ? 'Checking email...' : 'Validating address...'),
                  ],
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
}

import 'package:flutter/material.dart';

import '../models/client.dart';
import '../models/employee.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../theme/crud_modal_theme.dart';
import '../utils/error_text.dart';

Future<bool> showPersonalProfileModal(BuildContext context) async {
  final session = AuthSession.current;
  if (session == null) return false;
  final token = session.token.trim();
  if (token.isEmpty) return false;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) =>
        _PersonalProfileDialog(token: token, session: session),
  );
  return result == true;
}

class _PersonalProfileDialog extends StatefulWidget {
  const _PersonalProfileDialog({required this.token, required this.session});

  final String token;
  final AuthSessionState session;

  @override
  State<_PersonalProfileDialog> createState() => _PersonalProfileDialogState();
}

class _PersonalProfileDialogState extends State<_PersonalProfileDialog> {
  static const String _defaultEmployeePhotoAsset =
      '/assets/images/profiles/employee_default.png';
  final _api = ApiService();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  final _photoUrl = TextEditingController();
  final _preferredContactWindow = TextEditingController();
  String _preferredContactMethod = 'phone';

  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _editable = false;
  bool _employeeMode = false;
  bool _clientMode = false;
  String _title = 'My Profile';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _photoUrl.dispose();
    _preferredContactWindow.dispose();
    super.dispose();
  }

  String _assetPath(String? value, {required String fallback}) {
    final candidate = (value == null || value.trim().isEmpty)
        ? fallback
        : value.trim();
    return candidate.startsWith('/') ? candidate.substring(1) : candidate;
  }

  String _nullable(String value) {
    return value.trim();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = widget.session.user;
      if (user.isEmployee) {
        final employee = await _api.getEmployee(
          user.subjectId,
          bearerToken: widget.token,
        );
        _employeeMode = true;
        _editable = true;
        _title = 'Edit Employee Profile';
        _name.text = employee.name;
        _email.text = employee.email ?? (widget.session.loginEmail ?? '');
        _phone.text = employee.phoneNumber ?? '';
        _address.text = employee.address ?? '';
        _city.text = employee.city ?? '';
        _state.text = employee.state ?? '';
        _zip.text = employee.zipCode ?? '';
        _photoUrl.text = employee.photoUrl ?? _defaultEmployeePhotoAsset;
      } else if (user.isClient) {
        final client = await _api.getClient(
          user.subjectId,
          bearerToken: widget.token,
        );
        _clientMode = true;
        _editable = true;
        _title = 'Edit Client Profile';
        _name.text = client.name;
        _email.text = client.email ?? (widget.session.loginEmail ?? '');
        _phone.text = client.phoneNumber ?? '';
        _address.text = client.address ?? '';
        _city.text = client.city ?? '';
        _state.text = client.state ?? '';
        _zip.text = client.zipCode ?? '';
        _preferredContactMethod =
            (client.preferredContactMethod == null ||
                client.preferredContactMethod!.trim().isEmpty)
            ? 'phone'
            : client.preferredContactMethod!.trim().toLowerCase();
        _preferredContactWindow.text = client.preferredContactWindow ?? '';
      } else {
        _title = 'Admin Profile';
        _editable = false;
        final adminEmail = widget.session.loginEmail ?? '';
        _email.text = adminEmail;
        final local = adminEmail.split('@').first.trim();
        _name.text = local.isEmpty ? 'Admin' : local;
      }
    } catch (e) {
      _error = userFacingError(e);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _editPhotoPath() async {
    final controller = TextEditingController(text: _photoUrl.text);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile photo path'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Asset path',
            hintText: '/assets/images/profiles/employee_default.png',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (value == null) return;
    setState(() => _photoUrl.text = value);
  }

  Future<void> _save() async {
    if (!_editable || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_employeeMode) {
        await _api.updateEmployee(
          widget.session.user.subjectId,
          EmployeeUpdateInput(
            name: _nullable(_name.text),
            email: _nullable(_email.text),
            phoneNumber: _nullable(_phone.text),
            address: _nullable(_address.text),
            city: _nullable(_city.text),
            state: _nullable(_state.text),
            zipCode: _nullable(_zip.text),
            photoUrl: _nullable(_photoUrl.text),
          ),
          bearerToken: widget.token,
        );
      } else if (_clientMode) {
        await _api.updateClient(
          widget.session.user.subjectId,
          ClientUpdateInput(
            name: _nullable(_name.text),
            email: _nullable(_email.text),
            phoneNumber: _nullable(_phone.text),
            address: _nullable(_address.text),
            city: _nullable(_city.text),
            state: _nullable(_state.text),
            zipCode: _nullable(_zip.text),
            preferredContactMethod: _nullable(_preferredContactMethod),
            preferredContactWindow: _nullable(_preferredContactWindow.text),
          ),
          bearerToken: widget.token,
        );
      }
      AuthSession.set(
        AuthSessionState(
          token: widget.session.token,
          user: widget.session.user,
          loginEmail: _email.text.trim().isEmpty
              ? widget.session.loginEmail
              : _email.text.trim(),
          loginPassword: widget.session.loginPassword,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      enabled: _editable,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Color _titleColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB39CD0)
        : const Color(0xFF442E6F);
  }

  Color _avatarBgColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3B4250)
        : const Color(0xFFA8D6F7);
  }

  Color _errorColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFC1CC)
        : const Color(0xFFE63721);
  }

  Color _infoColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB8BCC4)
        : const Color(0xFF41588E);
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
              _title,
              style: TextStyle(color: _titleColor(context), fontWeight: FontWeight.w800),
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
        child: _loading
            ? const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_employeeMode) ...[
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _photoUrl,
                        builder: (context, value, _) => Stack(
                          children: [
                            CircleAvatar(
                              radius: 56,
                              backgroundColor: _avatarBgColor(context),
                              backgroundImage: AssetImage(
                                _assetPath(
                                  value.text,
                                  fallback: _defaultEmployeePhotoAsset,
                                ),
                              ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Edit profile photo',
                                onPressed: _editable ? _editPhotoPath : null,
                                icon: const Icon(Icons.edit, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _field(_name, 'Name'),
                    const SizedBox(height: 10),
                    _field(_email, 'Email'),
                    const SizedBox(height: 10),
                    _field(_phone, 'Phone'),
                    const SizedBox(height: 10),
                    _field(_address, 'Address'),
                    const SizedBox(height: 10),
                    _field(_city, 'City'),
                    const SizedBox(height: 10),
                    _field(_state, 'State'),
                    const SizedBox(height: 10),
                    _field(_zip, 'Zip Code'),
                    if (_clientMode) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _preferredContactMethod,
                        decoration: const InputDecoration(
                          labelText: 'Preferred Contact Method',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'phone',
                            child: Text('Phone'),
                          ),
                          DropdownMenuItem(
                            value: 'email',
                            child: Text('Email'),
                          ),
                          DropdownMenuItem(value: 'sms', child: Text('SMS')),
                        ],
                        onChanged: _editable
                            ? (value) {
                                if (value == null) return;
                                setState(() => _preferredContactMethod = value);
                              }
                            : null,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        _preferredContactWindow,
                        'Preferred Contact Window',
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: _errorColor(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    if (!_editable) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Admin profile updates are not enabled here yet.',
                          style: TextStyle(
                            color: _infoColor(context),
                            fontSize: 12,
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
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
        if (_editable)
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
      ],
      ),
    );
  }
}

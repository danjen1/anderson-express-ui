import 'package:flutter/material.dart';

import '../models/client.dart';
import '../models/employee.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../utils/error_text.dart';
import '../widgets/backend_banner.dart';
import '../widgets/profile_menu_button.dart';
import '../widgets/theme_toggle_button.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _isEditable = false;
  String _profileType = 'Account';

  String? get _token => AuthSession.current?.token.trim();

  @override
  void initState() {
    super.initState();
    final session = AuthSession.current;
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      });
      return;
    }
    _email.text = session.loginEmail ?? '';
    _loadProfile();
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
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final session = AuthSession.current;
    final token = _token;
    if (session == null || token == null || token.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ApiService();
      if (session.user.isEmployee) {
        final employee = await api.getEmployee(
          session.user.subjectId,
          bearerToken: token,
        );
        _fillFromEmployee(employee);
        _profileType = 'Employee Profile';
        _isEditable = true;
      } else if (session.user.isClient) {
        final client = await api.getClient(
          session.user.subjectId,
          bearerToken: token,
        );
        _fillFromClient(client);
        _profileType = 'Client Profile';
        _isEditable = true;
      } else {
        _profileType = 'Admin Account';
        _isEditable = false;
      }
    } catch (error) {
      _error = userFacingError(error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _fillFromEmployee(Employee employee) {
    _name.text = employee.name;
    _email.text = employee.email ?? _email.text;
    _phone.text = employee.phoneNumber ?? '';
    _address.text = employee.address ?? '';
    _city.text = employee.city ?? '';
    _state.text = employee.state ?? '';
    _zip.text = employee.zipCode ?? '';
  }

  void _fillFromClient(Client client) {
    _name.text = client.name;
    _email.text = client.email ?? _email.text;
    _phone.text = client.phoneNumber ?? '';
    _address.text = client.address ?? '';
    _city.text = client.city ?? '';
    _state.text = client.state ?? '';
    _zip.text = client.zipCode ?? '';
  }

  Future<void> _saveProfile() async {
    final session = AuthSession.current;
    final token = _token;
    if (session == null || token == null || token.isEmpty) return;
    if (!_isEditable) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final api = ApiService();
      if (session.user.isEmployee) {
        await api.updateEmployee(
          session.user.subjectId,
          EmployeeUpdateInput(
            name: _nullable(_name.text),
            email: _nullable(_email.text),
            phoneNumber: _nullable(_phone.text),
            address: _nullable(_address.text),
            city: _nullable(_city.text),
            state: _nullable(_state.text),
            zipCode: _nullable(_zip.text),
          ),
          bearerToken: token,
        );
      } else if (session.user.isClient) {
        await api.updateClient(
          session.user.subjectId,
          ClientUpdateInput(
            name: _nullable(_name.text),
            email: _nullable(_email.text),
            phoneNumber: _nullable(_phone.text),
            address: _nullable(_address.text),
            city: _nullable(_city.text),
            state: _nullable(_state.text),
            zipCode: _nullable(_zip.text),
          ),
          bearerToken: token,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      await _loadProfile();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_profileType),
        bottom: const BackendBanner(),
        actions: const [ThemeToggleButton(), ProfileMenuButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SelectionArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_error != null)
                        Card(
                          color: Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ),
                      if (!_isEditable)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'Admin self-profile editing is not wired to backend yet. Employee and Client profiles are editable now.',
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _isEditable && !_saving
                              ? _saveProfile
                              : null,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save Profile'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      enabled: _isEditable,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

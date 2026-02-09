import 'package:flutter/material.dart';

import '../mixins/base_api_page_mixin.dart';
import '../models/client.dart';
import '../models/employee.dart';
import '../services/auth_session.dart';
import '../utils/error_text.dart';
import '../widgets/backend_banner.dart';
import '../widgets/profile_menu_button.dart';
import '../widgets/theme_toggle_button.dart';
import '../utils/navigation_extensions.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with BaseApiPageMixin<ProfilePage> {
  static const String _defaultEmployeePhotoAsset =
      '/assets/images/profiles/employee_default.png';
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  final _photoUrl = TextEditingController();

  bool _saving = false;
  bool _isEditable = false;
  String _profileType = 'Account';

  String _assetPath(String? value, {required String fallback}) {
    final candidate = (value == null || value.trim().isEmpty)
        ? fallback
        : value.trim();
    return candidate.startsWith('/') ? candidate.substring(1) : candidate;
  }

  @override
  void initState() {
    super.initState();
    final session = AuthSession.current;
    if (session != null) {
      _email.text = session.loginEmail ?? '';
    }
  }

  @override
  bool checkAuthorization() {
    final session = AuthSession.current;
    if (session == null) return false;
    if (!session.user.isClient && !session.user.isEmployee && !session.user.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client or employee access required'),
        ),
      );
      context.navigateToHome();
      return false;
    }
    return true;
  }

  @override
  Future<void> loadData() async {
    final session = AuthSession.current;
    if (session == null || token == null || token!.isEmpty) return;

    if (session.user.isEmployee) {
      final employee = await api.getEmployee(
        session.user.subjectId,
        bearerToken: token!,
      );
      _fillFromEmployee(employee);
      _profileType = 'Employee Profile';
      _isEditable = true;
    } else if (session.user.isClient) {
      final client = await api.getClient(
        session.user.subjectId,
        bearerToken: token!,
      );
      _fillFromClient(client);
      _profileType = 'Client Profile';
      _isEditable = true;
    } else {
      _profileType = 'Admin Account';
      _isEditable = false;
    }
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
    super.dispose();
  }

  void _fillFromEmployee(Employee employee) {
    _name.text = employee.name;
    _email.text = employee.email ?? _email.text;
    _phone.text = employee.phoneNumber ?? '';
    _address.text = employee.address ?? '';
    _city.text = employee.city ?? '';
    _state.text = employee.state ?? '';
    _zip.text = employee.zipCode ?? '';
    _photoUrl.text = employee.photoUrl ?? '';
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
    if (session == null || token == null || token!.isEmpty) return;
    if (!_isEditable) return;

    setState(() {
      _saving = true;
    });
    setError(null);

    try {
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
            photoUrl: _nullable(_photoUrl.text),
          ),
          bearerToken: token!,
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
          bearerToken: token!,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      await reload();
    } catch (error) {
      if (!mounted) return;
      setError(userFacingError(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _showEmployeeEditModal() async {
    final session = AuthSession.current;
    if (session == null || !session.user.isEmployee) return;
    if (token == null || token!.isEmpty) return;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final name = TextEditingController(text: _name.text);
    final email = TextEditingController(text: _email.text);
    final phone = TextEditingController(text: _phone.text);
    final address = TextEditingController(text: _address.text);
    final city = TextEditingController(text: _city.text);
    final state = TextEditingController(text: _state.text);
    final zip = TextEditingController(text: _zip.text);
    final photo = TextEditingController(text: _photoUrl.text);
    Future<void> editPhotoPath() async {
      final picker = TextEditingController(text: photo.text);
      final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Employee photo path'),
          content: TextField(
            controller: picker,
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
              onPressed: () => Navigator.pop(context, picker.text.trim()),
              child: const Text('Apply'),
            ),
          ],
        ),
      );
      if (value == null) return;
      photo.text = value;
    }

    try {
      final submit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Expanded(child: Text('Edit Employee Details')),
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
                    valueListenable: photo,
                    builder: (context, value, _) {
                      final path = value.text.trim().isNotEmpty
                          ? value.text.trim()
                          : _defaultEmployeePhotoAsset;
                      return Stack(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: dark
                                ? const Color(0xFF3B4250)
                                : const Color(0xFFA8D6F7),
                            backgroundImage: AssetImage(
                              _assetPath(
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
                              tooltip: 'Edit photo path',
                              onPressed: editPhotoPath,
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
                        color: dark
                            ? const Color(0xFFFFC1CC)
                            : const Color(0xFF442E6F),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _field(name, 'Name *', enabled: true),
                  const SizedBox(height: 10),
                  _field(email, 'Email *', enabled: true),
                  const SizedBox(height: 10),
                  _field(phone, 'Phone', enabled: true),
                  const SizedBox(height: 10),
                  _field(address, 'Address', enabled: true),
                  const SizedBox(height: 10),
                  _field(city, 'City', enabled: true),
                  const SizedBox(height: 10),
                  _field(state, 'State', enabled: true),
                  const SizedBox(height: 10),
                  _field(zip, 'Zip Code', enabled: true),
                  const SizedBox(height: 10),
                  _field(photo, 'Photo URL', enabled: true),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (submit != true) return;

      await api.updateEmployee(
        session.user.subjectId,
        EmployeeUpdateInput(
          name: _nullable(name.text),
          email: _nullable(email.text),
          phoneNumber: _nullable(phone.text),
          address: _nullable(address.text),
          city: _nullable(city.text),
          state: _nullable(state.text),
          zipCode: _nullable(zip.text),
          photoUrl: _nullable(photo.text),
        ),
        bearerToken: token!,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Profile Updated'),
          content: const Text('Your employee profile details were saved.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _name.text = name.text;
      _email.text = email.text;
      _phone.text = phone.text;
      _address.text = address.text;
      _city.text = city.text;
      _state.text = state.text;
      _zip.text = zip.text;
      _photoUrl.text = photo.text;
      await reload();
    } catch (error) {
      if (!mounted) return;
      setError(userFacingError(error));
    } finally {
      name.dispose();
      email.dispose();
      phone.dispose();
      address.dispose();
      city.dispose();
      state.dispose();
      zip.dispose();
      photo.dispose();
    }
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget buildContent(BuildContext context) {
    return SelectionArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
              if (AuthSession.current?.user.isEmployee == true) ...[
                const SizedBox(height: 10),
                _field(_photoUrl, 'Photo URL'),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  if (AuthSession.current?.user.isEmployee == true)
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : _showEmployeeEditModal,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Details'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_profileType),
        bottom: const BackendBanner(),
        actions: const [ThemeToggleButton(), ProfileMenuButton()],
      ),
      body: buildBody(context),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool? enabled,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled ?? _isEditable,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

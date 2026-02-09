import 'package:flutter/material.dart';

import '../models/backend_config.dart';
import '../models/location.dart';
import '../services/api_service.dart';
import '../services/app_env.dart';
import '../services/auth_session.dart';
import '../services/backend_runtime.dart';
import '../utils/error_text.dart';
import '../widgets/backend_banner.dart';
import '../widgets/brand_app_bar_title.dart';
import '../widgets/demo_mode_notice.dart';
import '../widgets/profile_menu_button.dart';
import '../widgets/theme_toggle_button.dart';

class LocationsPage extends StatefulWidget {
  const LocationsPage({super.key});

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage> {
  final _clientFilterController = TextEditingController();
  late BackendKind _selectedBackend;
  late final TextEditingController _hostController;

  BackendConfig get _backend => BackendRuntime.config;
  ApiService get _api => ApiService();

  bool _loading = false;
  String? _error;
  List<Location> _locations = const [];
  bool _isAdmin = false;
  String? get _token => AuthSession.current?.token.trim();

  @override
  void initState() {
    super.initState();
    _selectedBackend = _backend.kind;
    _hostController = TextEditingController(text: BackendRuntime.host);
    final session = AuthSession.current;
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      });
      return;
    }
    _isAdmin = session.user.isAdmin;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!session.user.isAdmin && !session.user.isClient) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Locations access requires admin/client role'),
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }
      await _loadLocations();
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _clientFilterController.dispose();
    super.dispose();
  }

  Future<void> _applyBackendSelection() async {
    final host = BackendRuntime.normalizeHostInput(_hostController.text);
    final next = BackendConfig.forKind(
      _selectedBackend,
      host: host,
      scheme: BackendRuntime.scheme,
    );
    BackendRuntime.setConfig(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backend set to ${next.label} (${next.baseUrl})')),
    );
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _loadLocations() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Login required. Please sign in again.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final filterClientId = int.tryParse(_clientFilterController.text.trim());
      final locations = await _api.listLocations(
        clientId: filterClientId,
        bearerToken: token,
      );
      if (!mounted) return;
      setState(() {
        _locations = locations;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showCreateDialog() async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
    if (!_isAdmin) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Admin access required')));
      return;
    }
    final result = await showDialog<LocationCreateInput>(
      context: context,
      builder: (context) => const _LocationEditorDialog(),
    );

    if (result == null) return;

    try {
      await _api.createLocation(result, bearerToken: _token);
      await _loadLocations();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location created')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _showEditDialog(Location location) async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
    final result = await showDialog<LocationUpdateInput>(
      context: context,
      builder: (context) => _LocationEditorDialog(
        type: location.type,
        address: location.address ?? '',
        city: location.city ?? '',
        state: location.state ?? '',
        zipCode: location.zipCode ?? '',
        photoUrl: location.photoUrl ?? '',
        accessNotes: location.accessNotes ?? '',
        parkingNotes: location.parkingNotes ?? '',
        isCreate: false,
      ),
    );

    if (result == null) return;

    try {
      await _api.updateLocation(location.id, result, bearerToken: _token);
      await _loadLocations();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _delete(Location location) async {
    if (AppEnv.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode: create/edit/delete actions are disabled'),
        ),
      );
      return;
    }
    if (!_isAdmin) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Admin access required')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete location'),
        content: Text(
          'Delete ${location.locationNumber} (client ${location.clientId})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final message = await _api.deleteLocation(
        location.id,
        bearerToken: _token,
      );
      await _loadLocations();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandAppBarTitle(),
        bottom: const BackendBanner(),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            onPressed: _loading ? null : _loadLocations,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const ProfileMenuButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isAdmin && !AppEnv.isDemoMode ? _showCreateDialog : null,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add Location'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (BackendRuntime.allowBackendOverride) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [BackendKind.rust]
                    .map(
                      (kind) => ChoiceChip(
                        label: Text(switch (kind) {
                          BackendKind.rust => 'Rust',
                          _ => 'Rust',
                        }),
                        selected: _selectedBackend == kind,
                        onSelected: (_) {
                          setState(() => _selectedBackend = kind);
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'Backend Host',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _applyBackendSelection,
                    icon: const Icon(Icons.check),
                    label: const Text('Apply'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (AppEnv.isDemoMode) ...[
              const DemoModeNotice(
                message:
                    'Demo mode: location management is read-only in preview.',
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _clientFilterController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Client ID Filter (optional)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: _loadLocations,
                  icon: const Icon(Icons.filter_alt),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _locations.isEmpty
                  ? const Center(child: Text('No locations found'))
                  : ListView.separated(
                      itemCount: _locations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final location = _locations[index];
                        return Card(
                          child: ListTile(
                            leading: _locationThumb(location.photoUrl),
                            title: Text(location.locationNumber),
                            subtitle: Text(
                              'Client ${location.clientId} • ${location.type} • ${location.status}${location.address != null ? ' • ${location.address}' : ''}'
                              '${location.accessNotes != null ? '\nAccess: ${location.accessNotes}' : ''}',
                            ),
                            isThreeLine: location.accessNotes != null,
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                IconButton(
                                  onPressed: AppEnv.isDemoMode
                                      ? null
                                      : () => _showEditDialog(location),
                                  icon: const Icon(Icons.edit),
                                ),
                                if (_isAdmin)
                                  IconButton(
                                    onPressed: AppEnv.isDemoMode
                                        ? null
                                        : () => _delete(location),
                                    icon: const Icon(Icons.delete),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationThumb(String? photoUrl) {
    final url = photoUrl?.trim() ?? '';
    if (url.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.location_on));
    }
    final image = url.startsWith('/assets/')
        ? Image.asset(url.replaceFirst('/', ''), fit: BoxFit.cover)
        : Image.network(url, fit: BoxFit.cover);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 40, height: 40, child: image),
    );
  }
}

class _LocationEditorDialog extends StatefulWidget {
  const _LocationEditorDialog({
    this.type = 'residential',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.photoUrl = '',
    this.accessNotes = '',
    this.parkingNotes = '',
    this.isCreate = true,
  });

  final String type;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String photoUrl;
  final String accessNotes;
  final String parkingNotes;
  final bool isCreate;

  @override
  State<_LocationEditorDialog> createState() => _LocationEditorDialogState();
}

class _LocationEditorDialogState extends State<_LocationEditorDialog> {
  static const _types = ['residential', 'commercial'];

  late final TextEditingController _clientId;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zipCode;
  late final TextEditingController _photoUrl;
  late final TextEditingController _accessNotes;
  late final TextEditingController _parkingNotes;
  late String _type;

  @override
  void initState() {
    super.initState();
    _type = _types.contains(widget.type.toLowerCase())
        ? widget.type.toLowerCase()
        : _types.first;
    _clientId = TextEditingController();
    _address = TextEditingController(text: widget.address);
    _city = TextEditingController(text: widget.city);
    _state = TextEditingController(text: widget.state);
    _zipCode = TextEditingController(text: widget.zipCode);
    _photoUrl = TextEditingController(text: widget.photoUrl);
    _accessNotes = TextEditingController(text: widget.accessNotes);
    _parkingNotes = TextEditingController(text: widget.parkingNotes);
  }

  @override
  void dispose() {
    _clientId.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zipCode.dispose();
    _photoUrl.dispose();
    _accessNotes.dispose();
    _parkingNotes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isCreate ? 'Create Location' : 'Edit Location'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                items: _types
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _type = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.isCreate) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _clientId,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Client ID',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _field(_address, 'Address'),
              const SizedBox(height: 10),
              _field(_city, 'City'),
              const SizedBox(height: 10),
              _field(_state, 'State'),
              const SizedBox(height: 10),
              _field(_zipCode, 'Zip Code'),
              const SizedBox(height: 10),
              _field(
                _photoUrl,
                'Photo URL',
                hint: '/assets/images/locations/loc-9000.jpg',
              ),
              const SizedBox(height: 10),
              _field(_accessNotes, 'Access Notes', maxLines: 3),
              const SizedBox(height: 10),
              _field(_parkingNotes, 'Parking Notes', maxLines: 2),
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
              final parsedClientId = int.tryParse(_clientId.text.trim());
              if (parsedClientId == null || parsedClientId <= 0) {
                return;
              }

              Navigator.pop(
                context,
                LocationCreateInput(
                  type: _type,
                  clientId: parsedClientId,
                  address: _nullable(_address.text),
                  city: _nullable(_city.text),
                  state: _nullable(_state.text),
                  zipCode: _nullable(_zipCode.text),
                  photoUrl: _nullable(_photoUrl.text),
                  accessNotes: _nullable(_accessNotes.text),
                  parkingNotes: _nullable(_parkingNotes.text),
                ),
              );
            } else {
              Navigator.pop(
                context,
                LocationUpdateInput(
                  type: _type,
                  address: _nullable(_address.text),
                  city: _nullable(_city.text),
                  state: _nullable(_state.text),
                  zipCode: _nullable(_zipCode.text),
                  photoUrl: _nullable(_photoUrl.text),
                  accessNotes: _nullable(_accessNotes.text),
                  parkingNotes: _nullable(_parkingNotes.text),
                ),
              );
            }
          },
          child: Text(widget.isCreate ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

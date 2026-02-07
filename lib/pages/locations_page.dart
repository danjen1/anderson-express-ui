import 'package:flutter/material.dart';

import '../models/backend_config.dart';
import '../models/location.dart';
import '../services/api_service.dart';
import '../services/backend_runtime.dart';
import '../widgets/backend_banner.dart';

class LocationsPage extends StatefulWidget {
  const LocationsPage({super.key});

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage> {
  final _emailController = TextEditingController(
    text: 'admin@andersonexpress.com',
  );
  final _passwordController = TextEditingController(text: 'dev-password');
  final _tokenController = TextEditingController();
  final _clientFilterController = TextEditingController();
  late BackendKind _selectedBackend;
  late final TextEditingController _hostController;

  BackendConfig get _backend => BackendRuntime.config;
  ApiService get _api => ApiService();

  bool _loading = false;
  bool _hideToken = true;
  String? _error;
  List<Location> _locations = const [];

  @override
  void initState() {
    super.initState();
    _selectedBackend = _backend.kind;
    _hostController = TextEditingController(text: BackendRuntime.host);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    _clientFilterController.dispose();
    super.dispose();
  }

  Future<void> _applyBackendSelection() async {
    final host = _hostController.text.trim().isEmpty
        ? BackendRuntime.host
        : _hostController.text.trim();
    final next = BackendConfig.forKind(
      _selectedBackend,
      host: host,
      scheme: BackendRuntime.scheme,
    );
    BackendRuntime.setConfig(next);
    if (!mounted) return;
    setState(() {
      _error = null;
      _locations = const [];
      _tokenController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backend set to ${next.label} (${next.baseUrl})')),
    );
  }

  Future<void> _fetchToken() async {
    try {
      final token = await _api.fetchToken(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _tokenController.text = token;
      });
      await _loadLocations();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Token fetched')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _loadLocations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final filterClientId = int.tryParse(_clientFilterController.text.trim());
      final locations = await _api.listLocations(
        clientId: filterClientId,
        bearerToken: _tokenController.text,
      );
      if (!mounted) return;
      setState(() {
        _locations = locations;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
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
    final result = await showDialog<LocationCreateInput>(
      context: context,
      builder: (context) => const _LocationEditorDialog(),
    );

    if (result == null) return;

    try {
      await _api.createLocation(result, bearerToken: _tokenController.text);
      await _loadLocations();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location created')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showEditDialog(Location location) async {
    final result = await showDialog<LocationUpdateInput>(
      context: context,
      builder: (context) => _LocationEditorDialog(
        type: location.type,
        address: location.address ?? '',
        city: location.city ?? '',
        state: location.state ?? '',
        zipCode: location.zipCode ?? '',
        isCreate: false,
      ),
    );

    if (result == null) return;

    try {
      await _api.updateLocation(
        location.id,
        result,
        bearerToken: _tokenController.text,
      );
      await _loadLocations();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _delete(Location location) async {
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
        bearerToken: _tokenController.text,
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
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Locations'),
        bottom: const BackendBanner(),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadLocations,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add Location'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Backend: ${_backend.label} (${_backend.baseUrl})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BackendKind.values
                  .map(
                    (kind) => ChoiceChip(
                      label: Text(switch (kind) {
                        BackendKind.rust => 'Rust',
                        BackendKind.python => 'Python',
                        BackendKind.vapor => 'Vapor',
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
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Auth Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Auth Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _fetchToken,
                icon: const Icon(Icons.key),
                label: const Text('Fetch Token'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              obscureText: _hideToken,
              maxLines: 1,
              decoration: InputDecoration(
                labelText: 'Bearer Token',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _hideToken = !_hideToken);
                  },
                  icon: Icon(
                    _hideToken ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
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
            if (_tokenController.text.trim().isEmpty && _locations.isEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Fetch token first, then load locations.'),
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
                            leading: const Icon(Icons.location_on),
                            title: Text(location.locationNumber),
                            subtitle: Text(
                              'Client ${location.clientId} • ${location.type} • ${location.status}${location.address != null ? ' • ${location.address}' : ''}',
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                IconButton(
                                  onPressed: () => _showEditDialog(location),
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  onPressed: () => _delete(location),
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
}

class _LocationEditorDialog extends StatefulWidget {
  const _LocationEditorDialog({
    this.type = 'residential',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.isCreate = true,
  });

  final String type;
  final String address;
  final String city;
  final String state;
  final String zipCode;
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
  }

  @override
  void dispose() {
    _clientId.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zipCode.dispose();
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
                ),
              );
            }
          },
          child: Text(widget.isCreate ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

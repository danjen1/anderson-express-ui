import 'package:flutter/material.dart';

import '../mixins/base_api_page_mixin.dart';
import '../models/backend_config.dart';
import '../models/client.dart';
import '../models/location.dart';
import '../services/app_env.dart';
import '../services/auth_session.dart';
import '../services/backend_runtime.dart';
import '../utils/error_text.dart';
import '../utils/dialog_utils.dart';
import '../widgets/backend_banner.dart';
import '../widgets/brand_app_bar_title.dart';
import '../widgets/demo_mode_notice.dart';
import '../widgets/profile_menu_button.dart';
import '../widgets/theme_toggle_button.dart';
import '../utils/navigation_extensions.dart';
import '../widgets/admin/dialogs/location_editor_dialog.dart';

enum _LocationFilter { active, all, deleted }

class LocationsPage extends StatefulWidget {
  const LocationsPage({super.key});

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage>
    with BaseApiPageMixin<LocationsPage> {
  final _clientFilterController = TextEditingController();
  late BackendKind _selectedBackend;
  late final TextEditingController _hostController;

  List<Location> _locations = const [];
  List<Client> _clients = const [];
  _LocationFilter _locationFilter = _LocationFilter.active;
  int? _locationsSortColumnIndex;
  bool _locationsSortAscending = true;

  bool get _isAdmin => AuthSession.current?.user.isAdmin == true;

  @override
  void initState() {
    super.initState();
    _selectedBackend = backend.kind;
    _hostController = TextEditingController(text: BackendRuntime.host);
  }

  @override
  bool checkAuthorization() {
    final session = AuthSession.current;
    if (session == null) return false;
    if (!session.user.isAdmin && !session.user.isClient) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Locations access requires admin/client role'),
        ),
      );
      context.navigateToHome();
      return false;
    }
    return true;
  }

  @override
  Future<void> loadData() async {
    await Future.wait([_loadLocations(), _loadClients()]);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _clientFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    if (token == null || token!.isEmpty) return;
    try {
      final clients = await api.listClients(bearerToken: token!);
      if (!mounted) return;
      setState(() {
        _clients = clients;
      });
    } catch (error) {
      if (!mounted) return;
      setError(userFacingError(error));
    }
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
    context.navigateToHome();
  }

  Future<void> _loadLocations() async {
    if (token == null || token!.isEmpty) return;
    try {
      final filterClientId = int.tryParse(_clientFilterController.text.trim());
      final locations = await api.listLocations(
        clientId: filterClientId,
        bearerToken: token!,
      );
      if (!mounted) return;
      setState(() {
        _locations = locations;
      });
    } catch (error) {
      if (!mounted) return;
      setError(userFacingError(error));
    }
  }

  Future<void> _showCreateDialog() async {
    if (AppEnv.isDemoMode) {
      setError('Demo mode: create/edit/delete actions are disabled');
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
      builder: (context) =>
          LocationEditorDialog(clients: _clients, isCreate: true),
    );

    if (result == null) return;

    try {
      await api.createLocation(result, bearerToken: token);
      await _loadLocations();
      if (!mounted) return;
      showSuccessSnackBar(context, 'Location created successfully.');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  Future<void> _showEditDialog(Location location) async {
    if (AppEnv.isDemoMode) {
      setError('Demo mode: create/edit/delete actions are disabled');
      return;
    }
    final result = await showDialog<LocationUpdateInput>(
      context: context,
      builder: (context) => LocationEditorDialog(
        clients: _clients,
        clientId: location.clientId,
        status: location.status,
        type: location.type,
        address: location.address ?? '',
        city: location.city ?? '',
        state: location.state ?? '',
        zipCode: location.zipCode ?? '',
        photoUrl: location.photoUrl ?? '',
        isCreate: false,
        locationToEdit: location,
      ),
    );

    if (result == null) return;

    try {
      await api.updateLocation(location.id, result, bearerToken: token);
      await _loadLocations();
      if (!mounted) return;
      showSuccessSnackBar(context, 'Location updated successfully.');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    }
  }

  List<Location> get _filteredLocations {
    var filtered = _locations.where((location) {
      final status = location.status.trim().toLowerCase();
      switch (_locationFilter) {
        case _LocationFilter.active:
          return status == 'active';
        case _LocationFilter.deleted:
          return status == 'deleted';
        case _LocationFilter.all:
          return true;
      }
    }).toList();

    // Apply sorting
    if (_locationsSortColumnIndex != null) {
      filtered.sort((a, b) {
        int comparison = 0;
        switch (_locationsSortColumnIndex) {
          case 0: // Status
            final aStatus = a.status.trim().toLowerCase();
            final bStatus = b.status.trim().toLowerCase();
            comparison = aStatus.compareTo(bStatus);
            break;
          case 1: // Photo (no sort)
            comparison = 0;
            break;
          case 2: // Client Name
            final aClient = _clients.firstWhere(
              (c) => int.tryParse(c.id) == a.clientId,
              orElse: () => Client(
                id: a.clientId.toString(),
                clientNumber: '',
                name: '',
                status: '',
              ),
            );
            final bClient = _clients.firstWhere(
              (c) => int.tryParse(c.id) == b.clientId,
              orElse: () => Client(
                id: b.clientId.toString(),
                clientNumber: '',
                name: '',
                status: '',
              ),
            );
            comparison = aClient.name.toLowerCase().compareTo(
              bClient.name.toLowerCase(),
            );
            break;
          case 3: // Address
            comparison = (a.address ?? '').toLowerCase().compareTo(
              (b.address ?? '').toLowerCase(),
            );
            break;
        }
        return _locationsSortAscending ? comparison : -comparison;
      });
    }

    return filtered;
  }

  @override
  Widget buildContent(BuildContext context) {
    final filteredLocations = _filteredLocations;

    return Column(
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
            message: 'Demo mode: location management is read-only in preview.',
          ),
          const SizedBox(height: 12),
        ],
        // Status filter chips
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Active'),
                ],
              ),
              selected: _locationFilter == _LocationFilter.active,
              onSelected: (selected) {
                setState(() => _locationFilter = _LocationFilter.active);
              },
            ),
            FilterChip(
              label: const Text('All'),
              selected: _locationFilter == _LocationFilter.all,
              onSelected: (selected) {
                setState(() => _locationFilter = _LocationFilter.all);
              },
            ),
            FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Deleted'),
                ],
              ),
              selected: _locationFilter == _LocationFilter.deleted,
              onSelected: (selected) {
                setState(() => _locationFilter = _LocationFilter.deleted);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: filteredLocations.isEmpty
              ? const Center(child: Text('No locations found'))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      sortColumnIndex: _locationsSortColumnIndex,
                      sortAscending: _locationsSortAscending,
                      columns: [
                        DataColumn(
                          label: const Text(''),
                          onSort: (columnIndex, ascending) {
                            setState(() {
                              _locationsSortColumnIndex = columnIndex;
                              _locationsSortAscending = ascending;
                            });
                          },
                        ),
                        const DataColumn(label: Text('')), // Photo
                        DataColumn(
                          label: const Text('Client Name'),
                          onSort: (columnIndex, ascending) {
                            setState(() {
                              _locationsSortColumnIndex = columnIndex;
                              _locationsSortAscending = ascending;
                            });
                          },
                        ),
                        DataColumn(
                          label: const Text('Address'),
                          onSort: (columnIndex, ascending) {
                            setState(() {
                              _locationsSortColumnIndex = columnIndex;
                              _locationsSortAscending = ascending;
                            });
                          },
                        ),
                        const DataColumn(label: Text('')), // Details
                      ],
                      rows: filteredLocations.map((location) {
                        final status = location.status.trim().toLowerCase();
                        final statusColor = switch (status) {
                          'active' => Colors.green,
                          'inactive' => Colors.orange,
                          'deleted' => Colors.red,
                          _ => Colors.grey,
                        };

                        final client = _clients.firstWhere(
                          (c) => int.tryParse(c.id) == location.clientId,
                          orElse: () => Client(
                            id: location.clientId.toString(),
                            clientNumber: 'CLT-${location.clientId}',
                            name: 'Client ${location.clientId}',
                            status: 'unknown',
                          ),
                        );

                        return DataRow(
                          cells: [
                            // Status indicator
                            DataCell(
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            // Photo
                            DataCell(_locationThumb(location.photoUrl)),
                            // Client Name
                            DataCell(Text(client.name)),
                            // Address
                            DataCell(
                              Text(
                                location.address != null &&
                                        location.city != null
                                    ? '${location.address}, ${location.city}, ${location.state ?? ''}'
                                    : location.address ??
                                          location.city ??
                                          'No address',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Details button
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: AppEnv.isDemoMode
                                    ? null
                                    : () => _showEditDialog(location),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
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
            onPressed: isLoading ? null : reload,
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
        child: buildBody(context),
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
  const _LocationEditorDialog();

  final String type = 'residential';
  final String address = '';
  final String city = '';
  final String state = '';
  final String zipCode = '';
  final String photoUrl = '';
  final String accessNotes = '';
  final String parkingNotes = '';
  final bool isCreate = true;

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

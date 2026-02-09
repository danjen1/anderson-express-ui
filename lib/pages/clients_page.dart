import 'package:flutter/material.dart';

import '../mixins/base_api_page_mixin.dart';
import '../models/backend_config.dart';
import '../models/client.dart';
import '../services/app_env.dart';
import '../services/auth_session.dart';
import '../services/backend_runtime.dart';
import '../utils/error_text.dart';
import '../widgets/backend_banner.dart';
import '../widgets/brand_app_bar_title.dart';
import '../widgets/demo_mode_notice.dart';
import '../widgets/profile_menu_button.dart';
import '../widgets/theme_toggle_button.dart';
import '../utils/navigation_extensions.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> with BaseApiPageMixin<ClientsPage> {
  late BackendKind _selectedBackend;
  late final TextEditingController _hostController;

  List<Client> _clients = const [];

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
    if (!session.user.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin access required')),
      );
      context.navigateToHome();
      return false;
    }
    return true;
  }

  @override
  Future<void> loadData() async {
    await _loadClients();
  }

  @override
  void dispose() {
    _hostController.dispose();
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
    context.navigateToHome();
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

  Future<void> _showCreateDialog() async {
    if (AppEnv.isDemoMode) {
      setError('Demo mode: create/edit/delete actions are disabled');
      return;
    }
    final session = AuthSession.current;
    if (session == null || !session.user.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin access required')),
      );
      return;
    }

    final result = await showDialog<ClientCreateInput>(
      context: context,
      builder: (context) => const _ClientEditorDialog(),
    );
    if (result == null) return;

    try {
      final created = await api.createClient(result, bearerToken: token);
      await loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Client created. Invitation email requested for ${created.email ?? result.email}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setError(userFacingError(error));
    }
  }

  Future<void> _showEditDialog(Client client) async {
    if (AppEnv.isDemoMode) {
      setError('Demo mode: create/edit/delete actions are disabled');
      return;
    }
    final result = await showDialog<ClientUpdateInput>(
      context: context,
      builder: (context) => _ClientEditorDialog(
        name: client.name,
        email: client.email ?? '',
        phoneNumber: client.phoneNumber ?? '',
        address: client.address ?? '',
        city: client.city ?? '',
        state: client.state ?? '',
        zipCode: client.zipCode ?? '',
        preferredContactMethod: client.preferredContactMethod ?? '',
        preferredContactWindow: client.preferredContactWindow ?? '',
        serviceNotes: client.serviceNotes ?? '',
        isCreate: false,
      ),
    );
    if (result == null) return;

    try {
      await api.updateClient(client.id, result, bearerToken: token);
      await loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client updated')),
      );
    } catch (error) {
      if (!mounted) return;
      setError(userFacingError(error));
    }
  }

  Future<void> _delete(Client client) async {
    if (AppEnv.isDemoMode) {
      setError('Demo mode: create/edit/delete actions are disabled');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete client'),
        content: Text('Delete ${client.clientNumber} - ${client.name}?'),
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
      final message = await api.deleteClient(client.id, bearerToken: token);
      await loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      setError(userFacingError(error));
    }
  }

  @override
  Widget buildContent(BuildContext context) {
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
                    onSelected: (_) =>
                        setState(() => _selectedBackend = kind),
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
                'Demo mode: client management is read-only in preview.',
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: _clients.isEmpty
              ? const Center(child: Text('No clients found'))
              : ListView.separated(
                  itemCount: _clients.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final client = _clients[index];
                    return Card(
                      child: ListTile(
                        title: Text(client.name),
                        subtitle: Text(
                          '${client.clientNumber} • ${client.status}${client.email != null ? ' • ${client.email}' : ''}'
                          '${client.preferredContactMethod != null ? '\nContact: ${client.preferredContactMethod}' : ''}'
                          '${client.preferredContactWindow != null ? ' • ${client.preferredContactWindow}' : ''}',
                        ),
                        isThreeLine: client.preferredContactMethod != null,
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              onPressed: AppEnv.isDemoMode
                                  ? null
                                  : () => _showEditDialog(client),
                              icon: const Icon(Icons.edit),
                            ),
                            IconButton(
                              onPressed: AppEnv.isDemoMode
                                  ? null
                                  : () => _delete(client),
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
        onPressed: AppEnv.isDemoMode ? null : _showCreateDialog,
        icon: const Icon(Icons.business),
        label: const Text('Add Client'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: buildBody(context),
      ),
    );
  }
}

class _ClientEditorDialog extends StatefulWidget {
  const _ClientEditorDialog({
    this.name = '',
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

  final String name;
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
  State<_ClientEditorDialog> createState() => _ClientEditorDialogState();
}

class _ClientEditorDialogState extends State<_ClientEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zipCode;
  late final TextEditingController _preferredContactMethod;
  late final TextEditingController _preferredContactWindow;
  late final TextEditingController _serviceNotes;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _email = TextEditingController(text: widget.email);
    _phone = TextEditingController(text: widget.phoneNumber);
    _address = TextEditingController(text: widget.address);
    _city = TextEditingController(text: widget.city);
    _state = TextEditingController(text: widget.state);
    _zipCode = TextEditingController(text: widget.zipCode);
    _preferredContactMethod = TextEditingController(
      text: widget.preferredContactMethod,
    );
    _preferredContactWindow = TextEditingController(
      text: widget.preferredContactWindow,
    );
    _serviceNotes = TextEditingController(text: widget.serviceNotes);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zipCode.dispose();
    _preferredContactMethod.dispose();
    _preferredContactWindow.dispose();
    _serviceNotes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isCreate ? 'Create Client' : 'Edit Client'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              _field(_zipCode, 'Zip Code'),
              const SizedBox(height: 10),
              _field(
                _preferredContactMethod,
                'Preferred Contact Method',
                hint: 'email, phone, text',
              ),
              const SizedBox(height: 10),
              _field(
                _preferredContactWindow,
                'Preferred Contact Window',
                hint: 'Weekdays 8am-5pm',
              ),
              const SizedBox(height: 10),
              _field(
                _serviceNotes,
                'Service Notes',
                maxLines: 3,
                hint: 'Access preferences, special instructions, etc.',
              ),
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
              if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(
                context,
                ClientCreateInput(
                  name: _name.text.trim(),
                  email: _email.text.trim(),
                  phoneNumber: _nullable(_phone.text),
                  address: _nullable(_address.text),
                  city: _nullable(_city.text),
                  state: _nullable(_state.text),
                  zipCode: _nullable(_zipCode.text),
                  preferredContactMethod: _nullable(
                    _preferredContactMethod.text,
                  ),
                  preferredContactWindow: _nullable(
                    _preferredContactWindow.text,
                  ),
                  serviceNotes: _nullable(_serviceNotes.text),
                ),
              );
            } else {
              Navigator.pop(
                context,
                ClientUpdateInput(
                  name: _nullable(_name.text),
                  email: _nullable(_email.text),
                  phoneNumber: _nullable(_phone.text),
                  address: _nullable(_address.text),
                  city: _nullable(_city.text),
                  state: _nullable(_state.text),
                  zipCode: _nullable(_zipCode.text),
                  preferredContactMethod: _nullable(
                    _preferredContactMethod.text,
                  ),
                  preferredContactWindow: _nullable(
                    _preferredContactWindow.text,
                  ),
                  serviceNotes: _nullable(_serviceNotes.text),
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

import 'package:callvault/featurs/client_management/model/client_model.dart';
import 'package:callvault/featurs/client_management/service/client_storage_service.dart';
import 'package:flutter/material.dart';

class ClientManagementPage extends StatefulWidget {
  const ClientManagementPage({super.key});

  @override
  State<ClientManagementPage> createState() => _ClientManagementPageState();
}

class _ClientManagementPageState extends State<ClientManagementPage> {
  static const Color bg = Color(0xFF0F1729);
  static const Color cardBg = Color(0xFF1A2744);
  static const Color accent = Color(0xFF3B82F6);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color divider = Color(0xFF243456);

  final TextEditingController _searchController = TextEditingController();

  List<ClientModel> _clients = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final clients = await ClientStorageService.getClients();

    clients.sort(
      (a, b) =>
          a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase()),
    );

    if (!mounted) return;

    setState(() {
      _clients = clients;
      _loading = false;
    });
  }

  List<ClientModel> get _filteredClients {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _clients;
    }

    return _clients.where((client) {
      return client.clientName.toLowerCase().contains(query) ||
          client.phoneNumber.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _showClientDialog({ClientModel? client}) async {
    final nameController = TextEditingController(
      text: client?.clientName ?? '',
    );

    final phoneController = TextEditingController(
      text: client?.phoneNumber ?? '',
    );

    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cardBg,
              title: Text(
                client == null ? 'Add Client' : 'Edit Client',
                style: const TextStyle(color: textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(color: textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Client name',
                        labelStyle: TextStyle(color: textSecondary),
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        labelStyle: TextStyle(color: textSecondary),
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();

                    if (name.isEmpty || phone.isEmpty) {
                      setDialogState(() {
                        errorMessage =
                            'Client name and phone number are required.';
                      });
                      return;
                    }

                    final normalized =
                        ClientStorageService.normalizePhoneNumber(phone);

                    if (normalized.isEmpty) {
                      setDialogState(() {
                        errorMessage = 'Please enter a valid phone number.';
                      });
                      return;
                    }

                    final duplicate =
                        await ClientStorageService.phoneNumberExists(
                          phone,
                          excludingId: client?.id,
                        );

                    if (duplicate) {
                      setDialogState(() {
                        errorMessage = 'This phone number is already saved.';
                      });
                      return;
                    }

                    if (client == null) {
                      final newClient = ClientModel(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        clientName: name,
                        phoneNumber: phone,
                      );

                      await ClientStorageService.addClient(newClient);
                    } else {
                      final updatedClient = client.copyWith(
                        clientName: name,
                        phoneNumber: phone,
                      );

                      await ClientStorageService.updateClient(updatedClient);
                    }

                    if (!mounted) return;

                    Navigator.pop(dialogContext);
                    await _loadClients();

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          client == null ? 'Client added' : 'Client updated',
                        ),
                      ),
                    );
                  },
                  child: Text(client == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteClient(ClientModel client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardBg,
          title: const Text(
            'Delete Client',
            style: TextStyle(color: textPrimary),
          ),
          content: Text(
            'Delete ${client.clientName}?',
            style: const TextStyle(color: textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ClientStorageService.deleteClient(client.id);
    await _loadClients();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Client deleted')));
  }

  Widget _buildClientCard(ClientModel client) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.business_outlined, color: accent),
        ),
        title: Text(
          client.clientName,
          style: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            client.phoneNumber,
            style: const TextStyle(color: textSecondary),
          ),
        ),
        trailing: PopupMenuButton<String>(
          iconColor: textSecondary,
          color: cardBg,
          onSelected: (value) {
            if (value == 'edit') {
              _showClientDialog(client: client);
            }

            if (value == 'delete') {
              _deleteClient(client);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 10),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text('Delete', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredClients = _filteredClients;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        title: const Text(
          'Client Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: const TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Search name or phone number',
                hintStyle: const TextStyle(color: textSecondary),
                prefixIcon: const Icon(Icons.search, color: textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();

                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.close, color: textSecondary),
                      )
                    : null,
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: divider),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filteredClients.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people_outline,
                            color: textSecondary,
                            size: 58,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No clients saved'
                                : 'No matching clients',
                            style: const TextStyle(
                              color: textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Tap the Add Client button to create your first mapping.'
                                : 'Try another name or phone number.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadClients,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: filteredClients.length,
                      itemBuilder: (_, index) {
                        return _buildClientCard(filteredClients[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        onPressed: () => _showClientDialog(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Client'),
      ),
    );
  }
}

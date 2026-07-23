import 'dart:convert';

import 'package:callvault/featurs/client_management/model/client_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClientStorageService {
  static const String _storageKey = 'saved_clients';

  static Future<List<ClientModel>> getClients() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_storageKey);

    if (savedData == null || savedData.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(savedData);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map((item) => ClientModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveClients(List<ClientModel> clients) async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      clients.map((client) => client.toMap()).toList(),
    );

    await prefs.setString(_storageKey, encoded);
  }

  static Future<void> addClient(ClientModel client) async {
    final clients = await getClients();
    clients.add(client);
    await saveClients(clients);
  }

  static Future<void> updateClient(ClientModel updatedClient) async {
    final clients = await getClients();

    final index = clients.indexWhere((client) => client.id == updatedClient.id);

    if (index == -1) {
      return;
    }

    clients[index] = updatedClient;
    await saveClients(clients);
  }

  static Future<void> deleteClient(String id) async {
    final clients = await getClients();

    clients.removeWhere((client) => client.id == id);

    await saveClients(clients);
  }

  static Future<ClientModel?> findByPhoneNumber(String phoneNumber) async {
    final normalizedInput = normalizePhoneNumber(phoneNumber);
    final clients = await getClients();

    for (final client in clients) {
      final normalizedSaved = normalizePhoneNumber(client.phoneNumber);

      if (normalizedSaved == normalizedInput) {
        return client;
      }
    }

    return null;
  }

  static Future<bool> phoneNumberExists(
    String phoneNumber, {
    String? excludingId,
  }) async {
    final normalizedInput = normalizePhoneNumber(phoneNumber);
    final clients = await getClients();

    return clients.any((client) {
      if (excludingId != null && client.id == excludingId) {
        return false;
      }

      return normalizePhoneNumber(client.phoneNumber) == normalizedInput;
    });
  }

  static String normalizePhoneNumber(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }
}

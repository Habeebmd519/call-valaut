import 'package:callvault/core/helper_function/helper_function.dart';
import 'package:flutter/foundation.dart';

class ContactService {
  static Future<String?> findByNumber(String phoneNumber) async {
    final cleanNumber = phoneNumber.trim();

    if (cleanNumber.isEmpty || cleanNumber == 'Unknown') {
      return null;
    }

    try {
      final name = await NativeService.lookupContactName(cleanNumber);
      final cleanName = name?.trim();

      if (cleanName == null || cleanName.isEmpty) {
        return null;
      }

      return cleanName;
    } catch (e) {
      debugPrint('Device contact lookup failed: $e');
      return null;
    }
  }
}

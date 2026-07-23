import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void openBatteryOptimization() {
  const intent = AndroidIntent(
    action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
  );

  intent.launch();
}

Future<void> openAutoStartSettings() async {
  const intent = AndroidIntent(action: 'miui.intent.action.OP_AUTO_START');

  try {
    await intent.launch();
  } catch (e) {
    debugPrint('Could not open auto-start settings: $e');
  }
}

class NativeService {
  static const MethodChannel channel = MethodChannel('callvault/service');

  static Future<void> start(String watchPath) async {
    await channel.invokeMethod<void>('startService', {'watchPath': watchPath});
  }

  static Future<void> stop() async {
    await channel.invokeMethod<void>('stopService');
  }

  static Future<String?> lookupContactName(String phoneNumber) async {
    final number = phoneNumber.trim();

    if (number.isEmpty) {
      return null;
    }

    var permission = await Permission.contacts.status;

    if (!permission.isGranted) {
      permission = await Permission.contacts.request();
    }

    if (!permission.isGranted) {
      debugPrint('Contacts permission was not granted');
      return null;
    }

    try {
      final name = await channel.invokeMethod<String>('lookupContactName', {
        'phoneNumber': number,
      });

      final cleanName = name?.trim();

      if (cleanName == null || cleanName.isEmpty) {
        return null;
      }

      return cleanName;
    } on PlatformException catch (e) {
      debugPrint('Contact lookup failed: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Contact lookup failed: $e');
      return null;
    }
  }
}

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';

void openBatteryOptimization() {
  const AndroidIntent intent = AndroidIntent(
    action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
  );

  intent.launch();
}

Future<void> openAutoStartSettings() async {
  const intent = AndroidIntent(action: 'miui.intent.action.OP_AUTO_START');

  try {
    await intent.launch();
  } catch (e) {
    print(e);
  }
}

class NativeService {
  static const channel = MethodChannel("callvault/service");

  static Future<void> start(String watchPath) async {
    await channel.invokeMethod("startService", {"watchPath": watchPath});
  }

  static Future<void> stop() async {
    await channel.invokeMethod("stopService");
  }
}

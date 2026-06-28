import 'dart:convert';

import 'package:callvault/featurs/call_recording/models/call_recording.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String key = "recordings";

  static Future<void> save(CallRecording recording) async {
    final prefs = await SharedPreferences.getInstance();

    final list = prefs.getStringList(key) ?? [];

    list.add(jsonEncode(recording.toJson()));

    await prefs.setStringList(key, list);
  }

  static Future<List<CallRecording>> load() async {
    final prefs = await SharedPreferences.getInstance();

    final list = prefs.getStringList(key) ?? [];

    return list
        .map((e) => CallRecording.fromJson(jsonDecode(e)))
        .toList()
        .reversed
        .toList();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(key);
  }
}

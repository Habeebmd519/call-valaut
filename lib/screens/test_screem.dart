import 'dart:async';
import 'dart:io';

import 'package:callvault/core/helper_function/helper_function.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  List<String> files = [];

  Future<void> readFolder() async {
    final permission = await Permission.audio.request();

    if (!permission.isGranted) {
      print("Permission denied");
      return;
    }

    final directory = Directory(
      "/storage/emulated/0/Recordings/sound_recorder/call_rec",
    );

    if (!await directory.exists()) {
      print("Folder not found");
      return;
    }

    final list = directory.listSync();

    files.clear();

    for (final item in list) {
      if (item is File) {
        files.add(item.path);
      }
    }

    setState(() {});
  }

  StreamSubscription<FileSystemEvent>? watcher;

  void startWatching() {
    const path = "/storage/emulated/0/Recordings/sound_recorder/call_rec";

    final directory = Directory(path);

    if (!directory.existsSync()) {
      print("Folder not found");
      return;
    }

    print("Watching folder...");
    print(directory.path);

    watcher = directory.watch().listen((event) {
      print("-------------");
      print("Event Type : ${event.type}");
      print("Path       : ${event.path}");
      print("-------------");

      if (event is FileSystemCreateEvent) {
        print("NEW FILE CREATED");
      }
    });
  }

  @override
  void initState() {
    super.initState();
    readFolder();
    startWatching();
  }

  @override
  void dispose() {
    watcher?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("CallVault Test")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              await Permission.notification.request();
              print("back");
              NativeService.start();
            },

            child: const Text("Start Monitoring"),
          ),

          ElevatedButton(
            onPressed: () {
              openBatteryOptimization();
            },
            child: const Text("Battery Optimization"),
          ),
        ],
      ),
    );
  }
}

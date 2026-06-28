import 'dart:async';
import 'dart:io';

import 'package:callvault/core/helper_function/helper_function.dart';
import 'package:callvault/screens/recording_details_page.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:file_picker';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  List<String> files = [];
  bool started = false;

  bool loading = true;

  Future<void> readFolder(String path) async {
    print("READING: $path");

    final directory = Directory(path);

    print("Exists: ${await directory.exists()}");

    files.clear();

    final items = directory.listSync();

    print("Items = ${items.length}");

    for (final item in items) {
      print(item.path);

      if (item is File) {
        files.add(item.path);
      }
    }

    print("Files = ${files.length}");

    setState(() {});
  }

  StreamSubscription<FileSystemEvent>? watcher;

  void startWatching(String path) {
    final directory = Directory(path);

    if (!directory.existsSync()) return;

    watcher = directory.watch().listen((event) async {
      if (event is FileSystemCreateEvent || event is FileSystemModifyEvent) {
        await readFolder(path);
      }
    });
  }

  Future<void> editFolder() async {
    pathController.text = watchPath ?? "";

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Recording Folder"),
          content: TextField(
            controller: pathController,
            decoration: const InputDecoration(
              hintText: "/storage/emulated/0/...",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final value = pathController.text.trim();

                if (value.isEmpty) return;

                watchPath = value;

                await readFolder(value);

                watcher?.cancel();
                startWatching(value);

                if (mounted) {
                  setState(() {});
                }

                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> pickFolder() async {
    final String? path = await FilePicker.platform.getDirectoryPath();

    if (path == null) return;

    watchPath = path;

    watcher?.cancel();

    await readFolder(path);

    startWatching(path);

    setState(() {});
  }

  String? watchPath;
  final TextEditingController pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    loading = true;
    setState(() {});

    watchPath = await NativeService.findRecordingFolder();

    if (watchPath != null) {
      await readFolder(watchPath!);
      startWatching(watchPath!);
    }

    loading = false;
    setState(() {});
  }

  @override
  void dispose() {
    watcher?.cancel();
    pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        elevation: 0,
        title: const Text("CallVault"),
        centerTitle: true,
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          //------------------------------------------
          // STATUS CARD
          //------------------------------------------
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),

                    const SizedBox(width: 10),

                    const Text(
                      "Monitoring Active",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Watching Folder",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.folder_open, size: 20),
                      onPressed: pickFolder,
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    loading
                        ? "Searching..."
                        : (watchPath ?? "Recording folder not found"),
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          //------------------------------------------
          // BUTTONS
          //------------------------------------------
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: started
                      ? null
                      : () async {
                          // Notification permission
                          await Permission.notification.request();

                          // Android 13+
                          await Permission.audio.request();

                          // Android 12 and below
                          await Permission.storage.request();

                          if (watchPath == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Recording folder not found"),
                              ),
                            );
                            return;
                          }

                          await NativeService.start(watchPath!);

                          setState(() {
                            started = true;
                          });
                        },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Start"),
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: openBatteryOptimization,

                  icon: const Icon(Icons.battery_alert),

                  label: const Text("Battery"),
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          //------------------------------------------
          // FILES
          //------------------------------------------
          const Text(
            "Recent Recordings",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            )
          else if (files.isEmpty)
            Container(
              height: 150,
              alignment: Alignment.center,
              child: const Text(
                "No recordings found",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...files.reversed.map((e) {
              final file = File(e);

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecordingDetailsPage(file: file),
                      ),
                    );
                  },
                  leading: const CircleAvatar(child: Icon(Icons.music_note)),
                  title: Text(
                    file.uri.pathSegments.last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    "${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB",
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            }),
        ],
      ),
    );
  }
}

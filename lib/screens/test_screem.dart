import 'dart:io';

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

  @override
  void initState() {
    super.initState();
    readFolder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("CallVault Test")),
      body: ListView.builder(
        itemCount: files.length,
        itemBuilder: (_, index) {
          return ListTile(title: Text(files[index]));
        },
      ),
    );
  }
}

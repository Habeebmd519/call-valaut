import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class RecordingDetailsPage extends StatefulWidget {
  final File file;

  const RecordingDetailsPage({super.key, required this.file});

  @override
  State<RecordingDetailsPage> createState() => _RecordingDetailsPageState();
}

class _RecordingDetailsPageState extends State<RecordingDetailsPage> {
  final AudioPlayer player = AudioPlayer();

  bool playing = false;

  String phoneNumber = "Unknown";
  String date = "";
  String time = "";

  @override
  void initState() {
    super.initState();
    parseFileName();
  }

  void parseFileName() {
    final name = widget.file.path.split("/").last;

    //-----------------------------------
    // Phone Number
    //-----------------------------------

    try {
      final start = name.indexOf("(");
      final end = name.indexOf(")");

      if (start != -1 && end != -1) {
        phoneNumber = name.substring(start + 1, end);
      }
    } catch (_) {}

    //-----------------------------------
    // Date Time
    //-----------------------------------

    final match = RegExp(r'(\d{14})').firstMatch(name);

    if (match != null) {
      final value = match.group(1)!;

      date =
          "${value.substring(0, 4)}-${value.substring(4, 6)}-${value.substring(6, 8)}";

      time =
          "${value.substring(8, 10)}:${value.substring(10, 12)}:${value.substring(12, 14)}";
    }
  }

  Future<void> play() async {
    if (playing) {
      await player.stop();

      setState(() {
        playing = false;
      });

      return;
    }

    await player.play(DeviceFileSource(widget.file.path));

    setState(() {
      playing = true;
    });

    player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          playing = false;
        });
      }
    });
  }

  Widget item(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(value),
        ],
      ),
    );
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = (widget.file.lengthSync() / 1024 / 1024).toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(title: const Text("Recording Details")),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.music_note, size: 90, color: Colors.blue),

          const SizedBox(height: 20),

          Center(
            child: Text(
              widget.file.uri.pathSegments.last,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 30),

          item("Phone Number", phoneNumber),

          item("Date", date),

          item("Time", time),

          item("Size", "$size MB"),

          item("Path", widget.file.path),

          item("Upload Status", "Pending"),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: play,

            icon: Icon(playing ? Icons.stop : Icons.play_arrow),

            label: Text(playing ? "Stop" : "Play Recording"),
          ),
        ],
      ),
    );
  }
}

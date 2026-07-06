import 'dart:async';
import 'dart:io';

import 'package:callvault/core/helper_function/helper_function.dart';

import 'package:callvault/featurs/upload/upload_service.dart';
import 'package:callvault/screens/licence_screen.dart';
import 'package:callvault/screens/recording_details_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

// NOTE: `NativeService` was used in the original file (NativeService.start /
// NativeService.stop) but was never imported anywhere, which is a compile
// error. It must live somewhere in your project (it isn't defined in this
// file). Point this import at wherever that class actually is, e.g.:
// import 'package:callvault/core/native_service/native_service.dart';
// import 'package:callvault/core/native_service/native_service.dart';

// ---------------------------------------------------------------------------
// Upload status enum
// ---------------------------------------------------------------------------
enum UploadStatus { idle, uploading, done, failed }

// ---------------------------------------------------------------------------
// Model for a recording entry
// ---------------------------------------------------------------------------
class RecordingEntry {
  final File file;
  UploadStatus uploadStatus;

  RecordingEntry({required this.file, this.uploadStatus = UploadStatus.idle});
}

// Allowed recording extensions, hoisted out as a top-level const so it isn't
// recreated on every call to the folder scan.
const Set<String> _kAllowedExtensions = {
  "mp3",
  "m4a",
  "aac",
  "wav",
  "amr",
  "3gp",
  "ogg",
};

// ---------------------------------------------------------------------------
// TestPage (renamed internally to HomeScreen for premium feel)
// ---------------------------------------------------------------------------
class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> with TickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────────
  List<RecordingEntry> allRecordings = [];
  List<RecordingEntry> uploadedRecordings = [];

  bool started = false;
  bool loading = true;

  String? watchPath;

  // FIX: `watcher` was referenced throughout the original file (dispose,
  // initialize, pickFolder, startWatching) but was never declared as a field
  // — only left as a commented-out line. That's why the file didn't compile.
  // It's declared here (private, since nothing outside this State needs it).
  StreamSubscription<FileSystemEvent>? _watcher;

  // FIX: raw filesystem watch events fire multiple times in quick succession
  // for a single logical change (e.g. a recorder app writing a file in
  // chunks triggers several `modify` events). Debouncing collapses bursts of
  // events into a single rescan, which matters a lot once there are
  // hundreds/thousands of files to re-read.
  Timer? _debounceTimer;

  // FIX: keep recordings in a path -> entry map instead of scanning a List
  // with `firstWhere` on every refresh. Lookups become O(1) instead of O(n),
  // which is the main win for large folders (avoids the original code's
  // effectively O(n^2) rebuild on every fs event).
  final Map<String, RecordingEntry> _recordingsByPath = {};

  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // REMOVED: `pathController` (a TextEditingController) was declared and
  // disposed but never actually used anywhere in the widget tree — dead code.

  // ── Theme colours ─────────────────────────────────────────────────────────
  static const Color bg = Color(0xFF0F1729);
  static const Color cardBg = Color(0xFF1A2744);
  static const Color accent = Color(0xFF3B82F6);
  static const Color success = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color divider = Color(0xFF243456);

  // ── Server URL persistence ──────────────────────────────────────────────
  Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("server_url", url);
  }

  Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString("server_url") ??
        "https://n8n-642200590.kloudbeansite.com/webhook/call-upload";
  }

  Future<void> _showServerDialog() async {
    final controller = TextEditingController(text: await getServerUrl());

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Server URL"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "https://your-server/webhook",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await saveServerUrl(controller.text.trim());

              if (!mounted) return;
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Server URL updated")),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );

    // FIX: `controller` is a local TextEditingController that was never
    // disposed in the original code (small leak each time the dialog opens).
    controller.dispose();
  }

  // ── License check ─────────────────────────────────────────────────────────
  Future<void> checkLicense() async {
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey("first_open")) {
      await prefs.setInt("first_open", DateTime.now().millisecondsSinceEpoch);
    }

    final firstOpen = prefs.getInt("first_open")!;
    final activated = prefs.getBool("activated") ?? false;

    final doc = await FirebaseFirestore.instance
        .collection("app_config")
        .doc("app_config")
        .get();

    // REMOVED: the original code had several `print` statements here
    // (document keys, key lengths, trial_days value/type) left over from
    // debugging. They didn't affect behavior, just noise — stripped out.
    if (!doc.exists) {
      initialize();
      return;
    }

    final data = doc.data()!;

    final enabled = data["Enabled"] as bool? ?? true;
    final trialDays = int.tryParse(data["trial_days"].toString()) ?? 7;

    if (!enabled) {
      await prefs.remove("activated");
    }

    final daysUsed = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(firstOpen))
        .inDays;

    if (daysUsed >= trialDays && !activated) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ActivationPage()),
      );
      return;
    }

    initialize();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    checkLicense();
  }

  @override
  void dispose() {
    // FIX: cancel the debounce timer too, not just the stream subscription —
    // otherwise a pending Timer could fire after the State is disposed and
    // call setState on a dead widget.
    _debounceTimer?.cancel();
    _watcher?.cancel();
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Folder scanning ────────────────────────────────────────────────────────
  // Pure disk read: returns a fresh, sorted list of RecordingEntry for the
  // given folder. Does NOT touch State/setState — keeps this method testable
  // and reusable, and keeps I/O off the widget lifecycle.
  // Future<List<RecordingEntry>> _scanFolder(String path) async {
  //   final dir = Directory(path);

  //   print("Exists = ${await dir.exists()}");

  //   try {
  //     final list = dir.listSync();

  //     print("Count = ${list.length}");

  //     for (final e in list) {
  //       print(e.path);
  //     }
  //   } catch (e, s) {
  //     print(e);
  //     print(s);
  //   }

  //   return [];
  // }

  Future<List<RecordingEntry>> _scanFolder(String path) async {
    final directory = Directory(path);
    print("Scanning folder: $path");
    print("Exists: ${await directory.exists()}");
    if (!await directory.exists()) {
      return [];
    }

    // Collect matching files first (cheap, just path string checks).
    final List<File> matchingFiles = [];
    await for (final entity in directory.list(
      followLinks: false,
      recursive: true,
    )) {
      print("Entity: ${entity.path}");
      print("Type: ${entity.runtimeType}");

      if (entity is! File) continue;

      final dotIndex = entity.path.lastIndexOf('.');
      final ext = dotIndex == -1
          ? "NO EXTENSION"
          : entity.path.substring(dotIndex + 1);

      print("Extension: $ext");

      matchingFiles.add(entity);
    }
    // await for (final entity in directory.list(followLinks: false)) {
    //   print("Found: ${entity.path}");
    //   if (entity is! File) continue;

    //   final dotIndex = entity.path.lastIndexOf('.');
    //   // FIX: original code did `entity.path.split('.').last`, which throws
    //   // on a file with no extension at all. Guard against that instead.
    //   if (dotIndex == -1) continue;

    //   final extension = entity.path.substring(dotIndex + 1).toLowerCase();
    //   if (!_kAllowedExtensions.contains(extension)) continue;

    //   matchingFiles.add(entity);
    // }

    // FIX: fetch `lastModified` for all files in parallel instead of
    // sequentially awaiting inside a for-loop. This is the main performance
    // win for folders with hundreds/thousands of recordings — I/O is
    // overlapped instead of serialized.
    final modifiedTimes = await Future.wait(
      matchingFiles.map((f) => f.lastModified()),
    );

    // FIX: reuse existing RecordingEntry objects (via the path map) so an
    // in-progress/finished upload status survives a rescan, instead of the
    // original's `firstWhere(... orElse: () => RecordingEntry(...))` pattern
    // which was O(n) per file (O(n^2) overall) and still worked, but slowly.
    final entries = <RecordingEntry>[];
    for (var i = 0; i < matchingFiles.length; i++) {
      final file = matchingFiles[i];
      final existing = _recordingsByPath[file.path];
      entries.add(existing ?? RecordingEntry(file: file));
    }

    // Sort newest first using the modified times gathered above.
    final indices = List<int>.generate(entries.length, (i) => i);
    indices.sort((a, b) => modifiedTimes[b].compareTo(modifiedTimes[a]));

    print("Returning ${entries.length} entries");
    return [for (final i in indices) entries[i]];
  }

  // Re-scans the folder and applies the result to State, but only calls
  // setState if something actually changed (added/removed/reordered file).
  // This satisfies "avoid calling setState() unnecessarily" while still
  // guaranteeing the list reflects disk changes immediately.
  Future<void> _refreshRecordings(String path) async {
    final freshEntries = await _scanFolder(path);

    if (!mounted) return;

    final freshPaths = freshEntries.map((e) => e.file.path).toList();
    final currentPaths = allRecordings.map((e) => e.file.path).toList();

    final bool unchanged =
        freshPaths.length == currentPaths.length &&
        List.generate(
          freshPaths.length,
          (i) => freshPaths[i] == currentPaths[i],
        ).every((same) => same);

    if (unchanged) {
      // Nothing added, removed, or reordered — skip the rebuild entirely.
      return;
    }

    setState(() {
      allRecordings = freshEntries;

      // Rebuild the lookup map (prevents stale entries for deleted files,
      // and guarantees no duplicate keys/entries).
      _recordingsByPath
        ..clear()
        ..addEntries(freshEntries.map((e) => MapEntry(e.file.path, e)));

      uploadedRecordings = freshEntries
          .where((e) => e.uploadStatus == UploadStatus.done)
          .toList();
    });
  }

  // ── Folder watching ────────────────────────────────────────────────────────
  void _startWatching(String path) {
    // Guard against duplicate listeners (e.g. if this is ever called twice
    // for the same path without an intervening stop).
    _stopWatching();

    final directory = Directory(path);
    if (!directory.existsSync()) return;

    _watcher = directory.watch().listen((event) {
      // Debounce: collapse rapid bursts of fs events into one rescan.
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _refreshRecordings(path);
      });
    });
  }

  void _stopWatching() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _watcher?.cancel();
    _watcher = null;
  }

  // ── Initialization / folder selection ───────────────────────────────────────
  Future<void> initialize() async {
    setState(() => loading = true);

    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString("recording_folder");

    if (savedPath != null && await Directory(savedPath).exists()) {
      watchPath = savedPath;
      final entries = await _scanFolder(savedPath);

      if (!mounted) return;
      setState(() {
        allRecordings = entries;
        _recordingsByPath
          ..clear()
          ..addEntries(entries.map((e) => MapEntry(e.file.path, e)));
        uploadedRecordings = entries
            .where((e) => e.uploadStatus == UploadStatus.done)
            .toList();
      });

      _startWatching(savedPath);
    } else {
      watchPath = null;
      if (savedPath != null) {
        await prefs.remove("recording_folder");
      }
    }

    if (!mounted) return;
    setState(() => loading = false);

    if (watchPath == null && mounted) {
      pickFolder();
    }
  }

  Future<void> pickFolder() async {
    final String? path = await FilePicker.platform.getDirectoryPath();
    print("Selected path: $path");

    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select your call recording folder."),
        ),
      );
      return;
    }

    // Stop watching the old folder before switching.
    _stopWatching();

    setState(() {
      loading = true;
      watchPath = path;
      allRecordings = [];
      uploadedRecordings = [];
      _recordingsByPath.clear();
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("recording_folder", path);

    final entries = await _scanFolder(path);
    print("Entries found: ${entries.length}");

    if (!mounted) return;
    setState(() {
      allRecordings = entries;
      _recordingsByPath.addEntries(
        entries.map((e) => MapEntry(e.file.path, e)),
      );
      uploadedRecordings = entries
          .where((e) => e.uploadStatus == UploadStatus.done)
          .toList();
      loading = false;
    });
    print("allRecordings = ${allRecordings.length}");

    _startWatching(path);
  }

  // -- to mp3 convertional functions
  Future<File?> convertToMp3(File input) async {
    final output = input.path.replaceAll(RegExp(r'\.\w+$'), '.mp3');

    final session = await FFmpegKit.execute(
      '-y -i "${input.path}" -codec:a libmp3lame -qscale:a 2 "$output"',
    );

    final rc = await session.getReturnCode();

    if (ReturnCode.isSuccess(rc)) {
      return File(output);
    }

    print(await session.getAllLogsAsString());

    return null;
  }

  // ── Upload logic ──────────────────────────────────────────────────────────
  Future<void> uploadToServer(RecordingEntry entry) async {
    setState(() => entry.uploadStatus = UploadStatus.uploading);

    final mp3 = await convertToMp3(entry.file);

    if (mp3 == null) {
      if (!mounted) return;
      _onUploadFailed(entry);
      return;
    }

    try {
      final success = await UploadService.uploadRecording(mp3);

      if (!mounted) return;

      if (success) {
        _onUploadSucceeded(entry);
      } else {
        _onUploadFailed(entry);
      }
    } finally {
      if (await mp3.exists()) {
        await mp3.delete();
      }
    }
  }

  void _onUploadSucceeded(RecordingEntry entry) {
    setState(() {
      entry.uploadStatus = UploadStatus.done;

      if (!uploadedRecordings.contains(entry)) {
        uploadedRecordings.add(entry);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Recording uploaded successfully",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onUploadFailed(RecordingEntry entry) {
    setState(() => entry.uploadStatus = UploadStatus.failed);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Upload failed",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────
  Widget _buildUploadButton(RecordingEntry entry) {
    switch (entry.uploadStatus) {
      case UploadStatus.idle:
        return _iconBtn(
          Icons.cloud_upload_outlined,
          accent,
          () => uploadToServer(entry),
          tooltip: "Upload to server",
        );
      case UploadStatus.uploading:
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: accent),
        );
      case UploadStatus.done:
        return _iconBtn(Icons.cloud_done, success, null, tooltip: "Uploaded");
      case UploadStatus.failed:
        return _iconBtn(
          Icons.cloud_off,
          Colors.redAccent,
          () => uploadToServer(entry),
          tooltip: "Retry upload",
        );
    }
  }

  Widget _iconBtn(
    IconData icon,
    Color color,
    VoidCallback? onTap, {
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? "",
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _buildRecordingCard(RecordingEntry entry) {
    final file = entry.file;
    final name = file.uri.pathSegments.last;
    final sizeMb = (file.lengthSync() / 1024 / 1024).toStringAsFixed(2);

    return Container(
      key: ValueKey(file.path),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: divider, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecordingDetailsPage(file: file),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.graphic_eq,
                    color: Colors.white,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 14),

                // Name + size
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$sizeMb MB",
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Upload button
                _buildUploadButton(entry),

                const SizedBox(width: 8),

                // Chevron
                const Icon(Icons.chevron_right, color: textSecondary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingList(List<RecordingEntry> items, String emptyMsg) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return Center(child: Text(emptyMsg));
    }

    // FIX: use ListView.builder with a stable key per item (see
    // _buildRecordingCard's ValueKey above) so Flutter can efficiently diff
    // the list instead of rebuilding every card from scratch — this matters
    // once there are hundreds/thousands of recordings.
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (_, index) => _buildRecordingCard(items[index]),
    );
  }

  // ── Header (waveform + status) ─────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, __) => Opacity(
                  opacity: _pulseAnimation.value,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: started ? success : amber,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (started ? success : amber).withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                started ? "Monitoring Active" : "Not Monitoring",
                style: TextStyle(
                  color: started ? success : amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                "${allRecordings.length} recording${allRecordings.length == 1 ? '' : 's'}",
                style: const TextStyle(color: textSecondary, fontSize: 13),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Folder row
          Row(
            children: [
              const Icon(Icons.folder_outlined, color: textSecondary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loading
                      ? "Loading..."
                      : (watchPath ?? "Recording folder not found"),
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: pickFolder,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Change",
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  label: started ? "Running" : "Start Monitor",
                  icon: started ? Icons.check : Icons.play_arrow,
                  color: started ? success : accent,
                  onTap: started ? _stopMonitoring : _startMonitoring,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionButton(
                  label: "Battery",
                  icon: Icons.battery_alert_outlined,
                  color: amber,
                  onTap: openBatteryOptimization,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Split out of the inline closures in _buildHeader for readability/testability.
  Future<void> _stopMonitoring() async {
    await NativeService.stop();

    if (!mounted) return;
    setState(() => started = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Monitoring stopped")));
  }

  Future<void> _startMonitoring() async {
    await Permission.notification.request();
    await Permission.audio.request();
    await Permission.storage.request();

    if (watchPath == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Recording folder not found")),
      );
      return;
    }

    await NativeService.start(watchPath!);

    if (!mounted) return;
    setState(() => started = true);
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null && label != "Running" ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,

      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.graphic_eq,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "CallVault",
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          // ── Static header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _buildHeader(),
          ),

          const SizedBox(height: 16),

          // ── Tabs ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: divider),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.list_alt, size: 16),
                        const SizedBox(width: 6),
                        Text("All (${allRecordings.length})"),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_done_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text("Uploaded (${uploadedRecordings.length})"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Tab content ───────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All recordings
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: _buildRecordingList(
                    allRecordings,
                    "No recordings found.\nTap 'Change' to set your recording folder.",
                  ),
                ),

                // Uploaded recordings
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: _buildRecordingList(
                    uploadedRecordings,
                    "No uploads yet.\nTap the cloud icon on any recording to upload.",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: _showServerDialog,
        child: const Icon(Icons.settings),
      ),
    );
  }
}

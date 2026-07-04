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
  StreamSubscription<FileSystemEvent>? watcher;

  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final TextEditingController pathController = TextEditingController();

  // ── Theme colours ─────────────────────────────────────────────────────────
  static const Color bg = Color(0xFF0F1729);
  static const Color cardBg = Color(0xFF1A2744);
  static const Color accent = Color(0xFF3B82F6);
  static const Color success = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color divider = Color(0xFF243456);

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

    showDialog(
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

              if (mounted) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Server URL updated")),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

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

    if (!doc.exists) {
      print("Document doesn't exist");
      initialize();
      return;
    }

    final data = doc.data()!;
    print(data.keys.toList());

    for (final key in data.keys) {
      print("[$key] length=${key.length}");
    }

    final enabled = data["Enabled"] as bool;
    print(data["trial_days"]);
    print(data["trial_days"].runtimeType);
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
    watcher?.cancel();
    pathController.dispose();
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Folder logic ──────────────────────────────────────────────────────────
  Future<void> readFolder(String path) async {
    final directory = Directory(path);

    if (!await directory.exists()) {
      return;
    }

    const allowedExtensions = {"mp3", "m4a", "aac", "wav", "amr", "3gp", "ogg"};

    final List<RecordingEntry> entries = [];

    await for (final entity in directory.list()) {
      if (entity is! File) continue;

      final extension = entity.path.split('.').last.toLowerCase();

      if (!allowedExtensions.contains(extension)) {
        continue;
      }

      final existing = allRecordings.firstWhere(
        (r) => r.file.path == entity.path,
        orElse: () => RecordingEntry(file: entity),
      );

      entries.add(existing);
    }

    // Newest recordings first
    final modifiedTimes = <RecordingEntry, DateTime>{};

    for (final entry in entries) {
      modifiedTimes[entry] = await entry.file.lastModified();
    }

    entries.sort((a, b) => modifiedTimes[b]!.compareTo(modifiedTimes[a]!));

    if (!mounted) return;

    setState(() {
      allRecordings = entries;

      uploadedRecordings = entries
          .where((e) => e.uploadStatus == UploadStatus.done)
          .toList();
    });
  }

  void startWatching(String path) {
    watcher?.cancel();

    final directory = Directory(path);
    if (!directory.existsSync()) return;

    watcher = directory.watch().listen((event) async {
      if (event is FileSystemCreateEvent ||
          event is FileSystemModifyEvent ||
          event is FileSystemDeleteEvent ||
          event is FileSystemMoveEvent) {
        await readFolder(path);
      }
    });
  }

  Future<void> initialize() async {
    setState(() => loading = true);

    final prefs = await SharedPreferences.getInstance();

    watchPath = prefs.getString("recording_folder");

    if (watchPath != null) {
      final dir = Directory(watchPath!);

      if (await dir.exists()) {
        await readFolder(watchPath!);
        startWatching(watchPath!);
      } else {
        watchPath = null;
        await prefs.remove("recording_folder");
      }
    }

    setState(() => loading = false);

    if (watchPath == null && mounted) {
      pickFolder();
    }
  }

  Future<void> pickFolder() async {
    final String? path = await FilePicker.platform.getDirectoryPath();

    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select your call recording folder."),
        ),
      );
      return;
    }

    setState(() {
      loading = true;
      watchPath = path;
      allRecordings = [];
      uploadedRecordings = [];
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("recording_folder", path);

    await watcher?.cancel();
    watcher = null;

    await readFolder(path);
    startWatching(path);

    if (!mounted) return;
    setState(() {
      loading = false;
      watchPath = path;
    });
  }

  // ── Upload logic ──────────────────────────────────────────────────────────
  Future<void> uploadToServer(RecordingEntry entry) async {
    setState(() {
      entry.uploadStatus = UploadStatus.uploading;
    });

    final success = await UploadService.uploadRecording(entry.file);

    if (!mounted) return;

    if (success) {
      setState(() {
        entry.uploadStatus = UploadStatus.done;

        if (!uploadedRecordings.contains(entry)) {
          uploadedRecordings.add(entry);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: const Row(
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
    } else {
      setState(() {
        entry.uploadStatus = UploadStatus.failed;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (_, index) {
        return _buildRecordingCard(items[index]);
      },
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
                  onTap: started
                      ? () async {
                          await NativeService.stop();

                          setState(() {
                            started = false;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Monitoring stopped")),
                          );
                        }
                      : () async {
                          await Permission.notification.request();
                          await Permission.audio.request();
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
                          setState(() => started = true);
                        },
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
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.only(right: 16),
        //     child: Container(
        //       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        //       decoration: BoxDecoration(
        //         gradient: const LinearGradient(
        //           colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
        //         ),
        //         borderRadius: BorderRadius.circular(20),
        //       ),
        //       child: const Text(
        //         "PRO",
        //         style: TextStyle(
        //           color: Colors.white,
        //           fontSize: 11,
        //           fontWeight: FontWeight.w800,
        //           letterSpacing: 1,
        //         ),
        //       ),
        //     ),
        //   ),
        // ],
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
        child: const Icon(Icons.settings),
        onPressed: _showServerDialog,
      ),
    );
  }
}

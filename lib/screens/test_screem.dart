import 'dart:async';
import 'dart:io';

import 'package:callvault/core/helper_function/helper_function.dart';
import 'package:callvault/featurs/client_management/pressntation/screen/client_management_page.dart';

import 'package:callvault/screens/licence_screen.dart';
import 'package:callvault/screens/recording_details_page.dart';
import 'package:callvault/services/contact_service.dart';
import 'package:callvault/services/local_contact_service.dart';
import 'package:callvault/services/metadata_service.dart';
import 'package:callvault/services/upload_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// NOTE: `NativeService` was used in the original file (NativeService.start /
// NativeService.stop) but was never imported anywhere, which is a compile
// error. It must live somewhere in your project (it isn't defined in this
// file). Point this import at wherever that class actually is, e.g.:
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

  StreamSubscription<FileSystemEvent>? _watcher;
  Timer? _debounceTimer;

  final Map<String, RecordingEntry> _recordingsByPath = {};

  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late final TextEditingController _serverController;
  late final TextEditingController _clientNameController;

  // NEW: expandable FAB (speed-dial) state + animation.
  bool _fabOpen = false;
  late AnimationController _fabController;
  late Animation<double> _fabRotation;
  late Animation<double> _fabScale;

  String clientName = 'Unknown client';

  // ── Theme colours ─────────────────────────────────────────────────────────
  static const Color bg = Color(0xFF0F1729);
  static const Color cardBg = Color(0xFF1A2744);
  static const Color accent = Color(0xFF3B82F6);
  static const Color accent2 = Color(0xFF6366F1);
  static const Color success = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color divider = Color(0xFF243456);

  // ---- client-name persistence ----

  Future<void> saveClientName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('client_name', name.trim());
  }

  Future<String> getClientName() async {
    final prefs = await SharedPreferences.getInstance();

    final savedName = prefs.getString('client_name')?.trim();

    if (savedName == null || savedName.isEmpty) {
      return 'Unknown client';
    }

    return savedName;
  }
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

  Future<void> saveMonitoringState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("monitoring_started", value);
  }

  Future<bool> getMonitoringState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool("monitoring_started") ?? false;
  }

  //---- show server dialog
  Future<void> _showServerDialog() async {
    _serverController.text = await getServerUrl();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Server URL',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: _serverController,
          keyboardType: TextInputType.url,
          style: const TextStyle(color: textPrimary),
          cursorColor: accent,
          decoration: InputDecoration(
            hintText: 'https://your-server/webhook',
            hintStyle: const TextStyle(color: textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final newUrl = _serverController.text.trim();

              if (newUrl.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a server URL')),
                );
                return;
              }

              await saveServerUrl(newUrl);

              final savedUrl = await getServerUrl();

              debugPrint('✅ Server URL updated successfully');
              debugPrint('New URL: $newUrl');
              debugPrint('Saved URL: $savedUrl');

              if (!mounted) return;

              Navigator.pop(dialogContext);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Server URL updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // -- activation / license migration --

  Future<void> migrateActivationV2() async {
    final prefs = await SharedPreferences.getInstance();

    const migrationKey = 'activation_v2_trial_reset_completed_v2';

    final completed = prefs.getBool(migrationKey) ?? false;

    debugPrint('Trial reset migration completed: $completed');
    debugPrint('Old first_open: ${prefs.getInt('first_open')}');

    if (completed) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    await prefs.remove('activated');
    await prefs.setBool('activatedV2', false);
    await prefs.setInt('first_open', now);
    await prefs.setBool(migrationKey, true);

    debugPrint('New first_open: ${prefs.getInt('first_open')}');
    debugPrint('V2 trial reset completed');
  }

  // ── License check ─────────────────────────────────────────────────────────
  Future<void> checkLicense() async {
    await migrateActivationV2();

    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey('first_open')) {
      await prefs.setInt('first_open', DateTime.now().millisecondsSinceEpoch);
    }

    final firstOpenMilliseconds = prefs.getInt('first_open');

    if (firstOpenMilliseconds == null) {
      await _openActivationPage();
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('app_config')
          .get();

      // For a paid app, do not silently unlock when configuration is missing.
      if (!doc.exists) {
        debugPrint('Firestore app configuration does not exist');
        await _openActivationPage();
        return;
      }

      final data = doc.data();

      if (data == null) {
        await _openActivationPage();
        return;
      }

      final enabled = data['Enabled'] as bool? ?? false;

      final trialDays = int.tryParse(data['trial_days']?.toString() ?? '') ?? 7;

      if (!enabled) {
        await prefs.setBool('activatedV2', false);
      }

      final firstOpen = DateTime.fromMillisecondsSinceEpoch(
        firstOpenMilliseconds,
      );

      final daysUsed = DateTime.now().difference(firstOpen).inDays;

      final activatedV2 = prefs.getBool('activatedV2') ?? false;

      debugPrint('Enabled: $enabled');
      debugPrint('Trial days: $trialDays');
      debugPrint('Days used: $daysUsed');
      debugPrint('Activated V2: $activatedV2');

      if (!enabled || (daysUsed >= trialDays && !activatedV2)) {
        await _openActivationPage();
        return;
      }

      await initialize();
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('Firestore error: ${e.code} - ${e.message}');
      debugPrintStack(stackTrace: stackTrace);

      final activatedV2 = prefs.getBool('activatedV2') ?? false;

      if (activatedV2) {
        await initialize();
      } else {
        await _openActivationPage();
      }
    } catch (e, stackTrace) {
      debugPrint('License check failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      final activatedV2 = prefs.getBool('activatedV2') ?? false;

      if (activatedV2) {
        await initialize();
      } else {
        await _openActivationPage();
      }
    }
  }

  Future<void> _openActivationPage() async {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ActivationPage()),
    );
  }

  /// --- load client name
  Future<void> _loadClientName() async {
    final savedName = await getClientName();

    if (!mounted) return;

    setState(() {
      clientName = savedName;
    });

    debugPrint('Loaded client name: $savedName');
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _serverController = TextEditingController();
    _clientNameController = TextEditingController();

    _tabController = TabController(length: 2, vsync: this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // NEW: drives the FAB rotation (+  -> x) and the mini-FAB reveal.
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _fabRotation =
        Tween<double>(
          begin: 0,
          end: 0.125, // 45°
        ).animate(
          CurvedAnimation(parent: _fabController, curve: Curves.easeOutBack),
        );

    _fabScale = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOutBack,
    );

    _loadClientName();
    checkLicense();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _clientNameController.dispose();

    _debounceTimer?.cancel();
    _watcher?.cancel();
    _tabController.dispose();
    _pulseController.dispose();
    _fabController.dispose();

    super.dispose();
  }

  // ── Folder scanning ────────────────────────────────────────────────────────
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
      if (entity is! File) continue;

      final fileName = entity.uri.pathSegments.last;

      // Ignore temporary upload files
      if (fileName.startsWith('af_')) {
        continue;
      }

      final dotIndex = fileName.lastIndexOf('.');
      if (dotIndex == -1) continue;

      final extension = fileName.substring(dotIndex + 1).toLowerCase();

      if (!_kAllowedExtensions.contains(extension)) {
        continue;
      }

      matchingFiles.add(entity);
    }

    // FIX: fetch `lastModified` for all files in parallel instead of
    // sequentially awaiting inside a for-loop.
    final modifiedTimes = await Future.wait(
      matchingFiles.map((f) => f.lastModified()),
    );

    // FIX: reuse existing RecordingEntry objects (via the path map) so an
    // in-progress/finished upload status survives a rescan.
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
      return;
    }

    setState(() {
      allRecordings = freshEntries;

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
    _stopWatching();

    final directory = Directory(path);
    if (!directory.existsSync()) return;

    _watcher = directory.watch().listen((event) {
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

    await Permission.notification.request();
    await Permission.audio.request();
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();

    final prefs = await SharedPreferences.getInstance();

    final savedStarted = prefs.getBool("monitoring_started") ?? false;
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

      if (savedStarted) {
        await NativeService.start(savedPath);

        if (!mounted) return;

        setState(() {
          started = true;
        });
      }
    } else {
      watchPath = null;

      if (savedPath != null) {
        await prefs.remove("recording_folder");
      }

      if (!mounted) return;

      setState(() {
        started = false;
      });

      await saveMonitoringState(false);
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });

    if (watchPath == null) {
      pickFolder();
    }
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
    await saveMonitoringState(true);

    if (!mounted) return;

    setState(() {
      started = true;
    });
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

  // -- upload preparation --

  Future<File?> prepareUploadFile(File input) async {
    try {
      final output = File(
        '${input.parent.path}/af_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );

      await input.copy(output.path);
      return output;
    } catch (e) {
      debugPrint('Prepare upload file error: $e');
      return null;
    }
  }
  // ── Upload logic ──────────────────────────────────────────────────────────

  Future<void> uploadToServer(RecordingEntry entry) async {
    if (entry.uploadStatus == UploadStatus.uploading) {
      return;
    }

    setState(() {
      entry.uploadStatus = UploadStatus.uploading;
    });

    File? uploadFile;

    try {
      final metadata = await MetadataService.fromFile(entry.file);

      String contactName = 'Unknown';

      if (metadata.phoneNumber.isNotEmpty &&
          metadata.phoneNumber != 'Unknown') {
        contactName =
            await LocalContactService.findByNumber(metadata.phoneNumber) ??
            await ContactService.findByNumber(metadata.phoneNumber) ??
            'Unknown';
      }

      final completedMetadata = metadata.copyWith(contactName: contactName);

      uploadFile = await prepareUploadFile(entry.file);

      if (uploadFile == null) {
        if (mounted) {
          _onUploadFailed(entry);
        }
        return;
      }

      final success = await UploadService.uploadRecording(
        uploadFile,
        metadata: completedMetadata.copyWith(
          filename: uploadFile.uri.pathSegments.last,
        ),
      );

      if (!mounted) return;

      if (success) {
        _onUploadSucceeded(entry);
      } else {
        _onUploadFailed(entry);
      }
    } catch (e, stackTrace) {
      debugPrint('Upload exception: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _onUploadFailed(entry);
      }
    } finally {
      if (uploadFile != null && await uploadFile.exists()) {
        await uploadFile.delete();
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
    if (!file.existsSync()) {
      return const SizedBox.shrink();
    }

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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [accent, accent2],
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

                _buildUploadButton(entry),

                const SizedBox(width: 8),

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
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              color: textSecondary.withOpacity(0.6),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              emptyMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

  Future<void> _stopMonitoring() async {
    await NativeService.stop();
    await saveMonitoringState(false);

    if (!mounted) return;

    setState(() {
      started = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Monitoring stopped")));
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

  // ── Expandable FAB (speed dial) ────────────────────────────────────────────
  void _toggleFab() {
    setState(() {
      _fabOpen = !_fabOpen;
      _fabOpen ? _fabController.forward() : _fabController.reverse();
    });
  }

  void _closeFab() {
    if (!_fabOpen) return;
    setState(() {
      _fabOpen = false;
      _fabController.reverse();
    });
  }

  // Full-screen dimming barrier shown behind the open speed-dial so a tap
  // anywhere outside the menu closes it — also visually separates the menu
  // from the recording list beneath it.
  Widget _buildFabBarrier() {
    return IgnorePointer(
      ignoring: !_fabOpen,
      child: GestureDetector(
        onTap: _closeFab,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: _fabOpen ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Container(color: Colors.black.withOpacity(0.45)),
        ),
      ),
    );
  }

  // A single labelled mini-action in the speed dial: a text chip + a round
  // icon button, both fading/scaling in with a slight stagger.
  Widget _buildSpeedDialItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required double delay,
  }) {
    final curved = CurvedAnimation(
      parent: _fabController,
      curve: Interval(delay, 1.0, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (_, child) => Transform.scale(
        scale: curved.value,
        alignment: Alignment.centerRight,
        child: Opacity(opacity: curved.value.clamp(0.0, 1.0), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: color,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  _closeFab();
                  onTap();
                },
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildSpeedDialItem(
          icon: Icons.person_add_alt_1,
          label: "Client",
          color: accent2,
          delay: 0.05,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientManagementPage()),
            );
          },
        ),
        _buildSpeedDialItem(
          icon: Icons.settings_outlined,
          label: "Server",
          color: amber,
          delay: 0.0,
          onTap: _showServerDialog,
        ),

        // Main toggle button — rotates + and gains a subtle gradient glow.
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          // child: Ink(
          //   decoration: BoxDecoration(
          //     shape: BoxShape.circle,
          //     gradient: const LinearGradient(
          //       colors: [accent, accent2],
          //       begin: Alignment.topLeft,
          //       end: Alignment.bottomRight,
          //     ),
          //     boxShadow: [
          //       BoxShadow(
          //         color: accent.withOpacity(0.45),
          //         blurRadius: 16,
          //         spreadRadius: 1,
          //         offset: const Offset(0, 6),
          //       ),
          //     ],
          //   ),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [accent, accent2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.45),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ],
            ),

            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _toggleFab,
              child: SizedBox(
                width: 60,
                height: 60,
                child: RotationTransition(
                  turns: _fabRotation,
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
          // ),
        ),
      ],
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
                gradient: const LinearGradient(colors: [accent, accent2]),
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

      // Stack lets the dimming barrier + speed-dial float above the page
      // content without changing how the rest of the layout works.
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildHeader(),
              ),

              const SizedBox(height: 16),

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

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      child: _buildRecordingList(
                        allRecordings,
                        "No recordings found.\nTap 'Change' to set your recording folder.",
                      ),
                    ),
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

          // Dimming barrier — sits above the content, below the FAB itself.
          Positioned.fill(child: _buildFabBarrier()),
        ],
      ),

      floatingActionButton: _buildExpandableFab(),
    );
  }
}
